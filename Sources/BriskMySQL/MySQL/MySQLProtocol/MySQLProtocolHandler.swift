// *********************************************************************************************************************
// MIT License
//
// Copyright (c) 2019, 2020 Chris Reynolds
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//  History:
//
//  Date        Author  Description
//  ----        ------  -----------
//  2019-12-24  CDR     Initial Version
// *********************************************************************************************************************
import NIO

internal class MySQLProtocolHandler: ChannelDuplexHandler {
    typealias InboundIn = MySQLStandardPacket
    typealias OutboundIn = MySQLState
    typealias OutboundOut = MySQLStandardPacket

    // 224 - utf8mb4_unicode_ci
    static let utf8mb4_unicode_ci = 224

    private var state: MySQLState
    private unowned var compressedDecoder: MySQLCompressedPacketDecoder
    private unowned var compressedEncoder: MySQLCompressedPacketEncoder

    init(state: MySQLState, decoder: MySQLCompressedPacketDecoder, encoder: MySQLCompressedPacketEncoder) {
        self.compressedDecoder = decoder
        self.compressedEncoder = encoder
        self.state = state
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        state = unwrapOutboundIn(data)

        switch state {
        case .ping(_):
            var packet = MySQLStandardPacket()
            packet.writeInteger(MySQLStandardPacket.COM_PING)
            context.writeAndFlush(wrapOutboundOut(packet), promise: promise)

        default:
            promise?.fail(SQLError.protocolError)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var packet = unwrapInboundIn(data)

        #if DEBUG
        if packet.isOK() { print(packet.okInfo()) }
        if packet.isError() { print(packet.errorInfo()) }
        #endif

        switch state {
        case .initialHandshake(let connection, var params):
            _ = handleIntiialHandshakePacket(params: &params, packet: &packet, context: context).always { result in
                switch result {
                case .failure(let error):
                    connection.fail(error)
                default:
                    self.state = .handshakeResponse(connection: connection, params: params)
                }
            }

        case .handshakeResponse(let connection, let params):
            if packet.isOK() {
                // Notify the encoder / decoder to switch to compressed packets if appropriate.
                if params["compression"]! == "true" {
                    compressedDecoder.compressionEnabled = true
                    compressedEncoder.compressionEnabled = true
                }

                connection.succeed(MySQLConnection(params: params, channel: context.channel))
            } else if packet.isError() {
                connection.fail(SQLError.sqlError(packet.errorInfo()))
            } else if packet.isFastAuthenticationResult() {
                var response = MySQLStandardPacket(sequenceNumber: packet.sequenceNumber + 1)
                response.writeString(params["password"]!)
                _ = context.writeAndFlush(wrapOutboundOut(response))
            }

        case .ping(let result):
            if packet.isOK() {
                result.succeed(true)
            } else if packet.isError() {
                result.fail(SQLError.protocolError)
            }
        }
    }
}
