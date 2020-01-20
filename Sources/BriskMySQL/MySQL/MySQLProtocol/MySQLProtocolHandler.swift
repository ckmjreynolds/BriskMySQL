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
    // swiftlint:disable identifier_name
    static let utf8mb4_unicode_ci = 224
    // swiftlint:enable identifier_name

    var state: MySQLState
    unowned var compressedDecoder: MySQLCompressedPacketDecoder
    unowned var compressedEncoder: MySQLCompressedPacketEncoder

    init(state: MySQLState, decoder: MySQLCompressedPacketDecoder, encoder: MySQLCompressedPacketEncoder) {
        self.compressedDecoder = decoder
        self.compressedEncoder = encoder
        self.state = state
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        state = unwrapOutboundIn(data)

        switch state {
        case .ping:
            sendPing(context: context, promise: promise)

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
            _ = handleInitialHandshakePacket(context: context, packet: &packet, params: &params).map { _ in
                self.state = .handshakeResponse(connection: connection, params: params)
            }.whenFailure { error in
                connection.fail(error)
            }

        case .handshakeResponse(let connection, let params):
            handleHandshakeResponse(context: context, packet: &packet, connection: connection, params: params)

        case .ping(_, let result):
            handlePing(context: context, packet: &packet, result: result)

        case .idle:
            preconditionFailure("ERROR: Packet received where none expected!")
        }
    }
}
