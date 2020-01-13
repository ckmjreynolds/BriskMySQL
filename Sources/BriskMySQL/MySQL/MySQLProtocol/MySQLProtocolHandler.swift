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
/*
import NIO
/*
    // 224 - utf8mb4_unicode_ci
    static let utf8mb4_unicode_ci: Int = 224
*/

internal class MySQLProtocolHandler: ChannelDuplexHandler {
    typealias InboundIn = MySQLPacket
    typealias OutboundIn = MySQLState
    typealias OutboundOut = MySQLPacket

    private var state: MySQLState

    init(state: MySQLState) { self.state = state }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var packet = unwrapInboundIn(data)

        switch state {
        case .initialHandshake(let connection, let params):
            do {
                try handleIntiialHandshakePacket(params: params, packet: &packet, context: context)
                state = .handshakeResponse(connection: connection, params: params)
            }
            catch {
                connection.fail(error)
            }

        case .handshakeResponse(let connection, let params):
            print(packet.debugDescription)
            assert(packet.isOK)
            var response = MySQLPacket(sequenceNumber: 0)
            response.writeInteger(0x08, size: 1)

            _ = context.writeAndFlush(wrapOutboundOut(response))
            //connection.succeed(MySQLConnection(params: params, channel: context.channel))

        case .ping(_, _):
            break;
        }
    }
}
*/
