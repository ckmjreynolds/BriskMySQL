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
import Foundation
import NIO

public class MySQLConnection: SQLConnection {
    private let params: [String: String]
    private let channel: Channel

    public static func connect(url: URL, on eventLoop: EventLoop) -> EventLoopFuture<SQLConnection> {
        switch MySQLConnection.decodeURL(url: url) {
        case .failure(let error):
            return eventLoop.makeFailedFuture(error)

        case .success(let params):
            let bootstrap = ClientBootstrap(group: eventLoop).channelOption(
                ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            return bootstrap.connect(host: params["host"]!, port: Int(params["port"]!)!).flatMap { channel in
                let connection = eventLoop.makePromise(of: SQLConnection.self)
                let state = MySQLState.initialHandshake(connection: connection, params: params)
                /*
                                                                      I/O Request
                                                                      via `Channel` or
                                                                      `ChannelHandlerContext`
                                                                        |
                    +---------------------------------------------------+---------------+
                    |                           ChannelPipeline         |               |
                    |                                TAIL              \|/              |
                    |    +----------------------+           +-----------+----------+    |
                    |    | MySQLProtocolHandler |           | MySQLProtocolHandler |    |
                    |    +----------+-----------+           +-----------+----------+    |
                    |              /|\                                  |               |
                    |               |                                  \|/              |
                    |    +----------+-----------+           +-----------+----------+    |
                    |    | MySQLPacketDecoder   |           | MySQLPacketEncoder   |    |
                    |    +----------+-----------+           +-----------+----------+    |
                    |              /|\               HEAD               |               |
                    +---------------+-----------------------------------+---------------+
                                    |                                  \|/
                    +---------------+-----------------------------------+---------------+
                    |               |                                   |               |
                    |       [ Socket.read ]                     [ Socket.write ]        |
                    |                                                                   |
                    |  SwiftNIO Internal I/O Threads (Transport Implementation)         |
                    +-------------------------------------------------------------------+
                */
                return channel.pipeline.addHandler(ByteToMessageHandler(MySQLPacketDecoder()),
                                                   name: "MySQLPacketDecoder", position: .last).flatMap {
                    return channel.pipeline.addHandler(MessageToByteHandler(MySQLPacketEncoder()),
                                                       name: "MySQLPacketEncoder", position: .last)
                }.flatMap { _ in
                    return channel.pipeline.addHandler(MySQLProtocolHandler(state: state),
                                                       name: "MySQLProtocolHandler", position: .last)
                }.flatMap { _ in
                    return connection.futureResult
                }
            }
        }
    }

    public func close() -> EventLoopFuture<Void> {
        channel.close(mode: .all)
    }

    internal init(params: [String: String], channel: Channel) {
        self.params = params
        self.channel = channel
    }
}

extension MySQLConnection {
    static private let configKeys = ["user", "password", "host", "port", "database"]

    /// Decode the DB url into its component parts.
    internal static func decodeURL(url: URL) -> Result<[String: String], SQLError> {
        // Verify and decode the required parts.
        guard (url.scheme ?? "") == "mysql" else { return .failure(.invalidURL) }
        guard let user = url.user else { return .failure(.invalidURL) }
        guard let password = url.password else { return .failure(.invalidURL) }
        guard let host = url.host, host.count > 0 else { return .failure(.invalidURL) }
        guard let port = url.port else { return .failure(.invalidURL) }

        // Create a dictionary with all of the required components.
        var dict = ["user": user, "password": password, "host": host, "port": String(port),
                    "database": url.lastPathComponent]

        // Parse any options that were added to the URL.
        for query in (url.query ?? "").split(separator: "&") {
            let param = query.split(separator: "=")
            guard param.count == 2 else { return .failure(.invalidURL)}

            dict[String(param[0])] = String(param[1])
        }

        // Check to make sure known keys are present.
        if dict.filter({ !configKeys.contains($0.key) }).count != 0 {
            return .failure(.invalidURL)
        }
        return .success(dict)
    }
}
