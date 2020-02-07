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
//  2020-02-07  CDR     Update dependencies:
//                      - swift-crypto 1.0.0
// *********************************************************************************************************************
import Foundation
import NIO
import NIOSSL
import Crypto

extension MySQLProtocolHandler {
    // Punting these warnings, do not see a benefit to breaking down handling of this one packet.
    // swiftlint:disable cyclomatic_complexity function_body_length
    /**
     Initial Handshake Packet
     https://mariadb.com/kb/en/connection/#initial-handshake-packet
    */
    func handleInitialHandshakePacket(context: ChannelHandlerContext, packet: inout MySQLStandardPacket,
                                      params: inout [String: String]) -> EventLoopFuture<Void> {

        var done: EventLoopFuture<Void>

        // Store the decoded handshake here for diagnostic purposes.
        var handshake = [(tag: String, value: String?)]()
        var tempInt: UInt?
        var tempBytes: [UInt8]?

        // int<1> protocol version
        tempInt = packet.readInteger(encoding: .fixedLength(length: 1))
        handshake.append(("protocol version", tempInt.debugDescription))

        // string<NUL> server version (MariaDB server version is by default prefixed by "5.5.5-")
        handshake.append(("server version", packet.readString()))

        // int<4> connection id
        tempInt = packet.readInteger(encoding: .fixedLength(length: 4))
        handshake.append(("connection id", tempInt.debugDescription))

        // string<8> scramble 1st part (authentication seed)
        let scramble1 = packet.readBytes(encoding: .fixedLength(length: 8))
        handshake.append(("scramble 1st part", scramble1?.debugDescription))

        // string<1> reserved byte
        tempBytes = packet.readBytes(encoding: .fixedLength(length: 1))
        handshake.append(("reserved byte", tempBytes?.debugDescription))

        // int<2> server capabilities (1st part)
        let capabilities1: UInt64? = packet.readInteger(encoding: .fixedLength(length: 2))
        handshake.append(("server capabilities (1st part)", capabilities1.debugDescription))

        // int<1> server default collation
        tempInt = packet.readInteger(encoding: .fixedLength(length: 1))
        handshake.append(("server default collation", tempInt.debugDescription))

        // int<2> status flags
        tempInt = packet.readInteger(encoding: .fixedLength(length: 2))
        handshake.append(("status flags", tempInt.debugDescription))

        // int<2> server capabilities (2nd part)
        let capabilities2: UInt64? = packet.readInteger(encoding: .fixedLength(length: 2))
        handshake.append(("server capabilities (2nd part)", capabilities2.debugDescription))

        // int<1> plugin data length
        let pluginDataLength: UInt64? = packet.readInteger(encoding: .fixedLength(length: 1))
        handshake.append(("plugin data length", pluginDataLength.debugDescription))

        // string<6> filler
        tempBytes = packet.readBytes(encoding: .fixedLength(length: 6))
        handshake.append(("filler", tempBytes?.debugDescription))

        // int<4> server capabilities 3rd part . MariaDB specific flags /* MariaDB 10.2 or later */
        let capabilities3: UInt64? = packet.readInteger(encoding: .fixedLength(length: 4))
        handshake.append(("server capabilities (3rd part)", capabilities3.debugDescription))

        // string<n> scramble 2nd part . Length = max(12, plugin data length - 9)
        let scramble2 = packet.readBytes(encoding: .fixedLength(length: Int(max(12, (pluginDataLength ?? 21) - 9))))
        handshake.append(("scramble 2nd part", scramble2?.debugDescription))

        // string<1> reserved byte
        tempBytes = packet.readBytes(encoding: .fixedLength(length: 1))
        handshake.append(("reserved byte", tempBytes?.debugDescription))

        // string<NUL> authentication plugin name
        let pluginName = packet.readString()
        handshake.append(("authentication plugin name", pluginName))

        #if DEBUG
        for entry in handshake { print(entry.tag + ": " + (entry.value ?? "nil")) }
        #endif

        // Validate that we parsed the handshake packet correctly.
        // NOTE: This means force unwrapping is safe from here.
        guard !handshake.contains(where: { $0.value == nil }) else {
            return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
        }

        // Combine all the flags and make sure the ones we depend on are correct.
        let flags = MySQLCapabilities(rawValue: capabilities3! << 32 | capabilities2! << 16 | capabilities1!)

        // Validate that we processed the entire packet and check flags that we depend on.
        // NOTE: We support COMPRESSion and SSL as well but do not require either.
        let requiredCapabilities: [MySQLCapabilities] = [.CONNECT_WITH_DB, .CLIENT_PROTOCOL_41, .SECURE_CONNECTION]
        guard flags.isStrictSuperset(of: MySQLCapabilities(requiredCapabilities)) else {
            return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
        }

        // Create the Handshake Response Packet.
        // https://mariadb.com/kb/en/connection/#handshake-response-packet
        var response = MySQLStandardPacket(sequenceNumber: packet.sequenceNumber + 1)

        var clientFlags = MySQLCapabilities(arrayLiteral: [.CONNECT_WITH_DB, .CLIENT_PROTOCOL_41,
                                                           .SECURE_CONNECTION, .PLUGIN_AUTH])

        // Enable compression if it is supported by the server.
        if params["compression"]! != "disabled" && flags.contains(.COMPRESS) {
            clientFlags.insert(.COMPRESS)
            params["compression"] = "true"
        } else if params["compression"]! == "true" && !flags.contains(.COMPRESS) {
            return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
        }

        // Enable SSL if it is supported by the server.
        if params["ssl"]! != "disabled" && flags.contains(.SSL) {
            clientFlags.insert(.SSL)
            params["ssl"] = "true"
        } else if params["ssl"]! == "true" && !flags.contains(.SSL) {
            return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
        }

        // int<4> client capabilities
        response.writeInteger(clientFlags.rawValue, encoding: .fixedLength(length: 4))

        // int<4> max packet size
        response.writeInteger(MySQLStandardPacket.maxPacketLength, encoding: .fixedLength(length: 4))

        // int<1> client character collation
        // 224 - utf8mb4_unicode_ci
        response.writeInteger(MySQLProtocolHandler.utf8mb4_unicode_ci, encoding: .fixedLength(length: 1))

        // string<19> reserved
        // if not (server_capabilities & CLIENT_MYSQL)
        //      int<4> extended client capabilities
        // else
        //      string<4> reserved
        response.writeBytes([UInt8](repeating: 0, count: 23))

        // Write the SSL response and add an SSL handler if we are turning on SSL.
        if clientFlags.contains(.SSL) {
            done = context.writeAndFlush(wrapOutboundOut(response)).flatMap { _ in
                response.sequenceNumber += 1

                // No certificate verification.
                var tlsConfiguration = TLSConfiguration.clientDefault
                tlsConfiguration.certificateVerification = .none

                // Add the handler to the pipeline.
                let sslContext = try? NIOSSLContext(configuration: tlsConfiguration)
                let handler = try? NIOSSLClientHandler(context: sslContext!, serverHostname: nil)

                return context.channel.pipeline.addHandler(handler!, position: .first)
            }
        } else {
            done = context.eventLoop.makeSucceededFuture(())
        }

        let user = params["user"]!
        let password = params["password"]!
        let database = params["database"]!

        return done.flatMap { _ in
            // string<NUL> username
            response.writeString(user)

            // else if (server_capabilities & CLIENT_SECURE_CONNECTION)
            //      int<1> length of authentication response
            //      string<fix> authentication response (length is indicated by previous field)
            //
            var passwordHash1: [UInt8], passwordHash2: [UInt8], saltedHash: [UInt8], authResponse: [UInt8]
            let seed = scramble1! + scramble2!

            switch pluginName {
            case "mysql_native_password":
                // The password is encrypted with: SHA1( password ) ^ SHA1( seed + SHA1( SHA1( password ) ) )
                var sha1 = Insecure.SHA1()
                sha1.update(data: Data(password.utf8))
                passwordHash1 = [UInt8](sha1.finalize())

                sha1 = Insecure.SHA1()
                sha1.update(data: Data(passwordHash1))
                passwordHash2 = [UInt8](sha1.finalize())

                sha1 = Insecure.SHA1()
                sha1.update(data: Data(seed + passwordHash2))
                saltedHash = [UInt8](sha1.finalize())

            case "caching_sha2_password":
                // caching_sha2_password requires a SSL/TLS connection.
                if !clientFlags.contains(.SSL) {
                    return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
                }

                // Encryption is XOR(SHA256(password), SHA256(seed, SHA256(SHA256(password))))
                var sha256 = SHA256()
                sha256.update(data: Data(password.utf8))
                passwordHash1 = [UInt8](sha256.finalize())

                sha256 = SHA256()
                sha256.update(data: Data(passwordHash1))
                passwordHash2 = [UInt8](sha256.finalize())

                sha256 = SHA256()
                sha256.update(data: Data(seed + passwordHash2))
                saltedHash = [UInt8](sha256.finalize())

            default:
                return context.channel.eventLoop.makeFailedFuture(SQLError.protocolError)
            }

            authResponse = passwordHash1.enumerated().map { $0.element ^ saltedHash[$0.offset] }
            response.writeInteger(authResponse.count, encoding: .fixedLength(length: 1))
            response.writeBytes(authResponse)

            // if (server_capabilities & CLIENT_CONNECT_WITH_DB)
            //      string<NUL> default database name
            response.writeString(database)

            // if (server_capabilities & CLIENT_PLUGIN_AUTH)
            //      string<NUL> authentication plugin name
            response.writeString(pluginName!)

            // Send the response.
            return context.writeAndFlush(self.wrapOutboundOut(response))
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
