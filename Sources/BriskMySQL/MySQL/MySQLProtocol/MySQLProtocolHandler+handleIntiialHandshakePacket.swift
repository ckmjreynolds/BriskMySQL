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
import CryptoSwift

extension MySQLProtocolHandler {
    /**
Initial Handshake Packet
https://mariadb.com/kb/en/connection/#initial-handshake-packet

string<n> scramble 2nd part . Length = max(12, plugin data length - 9)
string<1> reserved byte
if (server_capabilities & PLUGIN_AUTH)
string<NUL> authentication plugin name
     */
    func handleIntiialHandshakePacket(params: [String: String], packet: inout MySQLPacket,
                                      context: ChannelHandlerContext) throws {
        // int<1> protocol version
        guard let protocolVersion = packet.readUInt8() else { throw SQLError.protocolError() }

        // string<NUL> server version (MariaDB server version is by default prefixed by "5.5.5-")
        let serverVersion = packet.readCString()

        // int<4> connection id
        guard let connectionId = packet.readUInt32() else { throw SQLError.protocolError() }

        // string<8> scramble 1st part (authentication seed)
        guard let scramble1 = packet.readBytes(length: 8) else { throw SQLError.protocolError() }

        // string<1> reserved byte
        guard let reserved1 = packet.readUInt8() else { throw SQLError.protocolError() }

        // int<2> server capabilities (1st part)
        guard let serverCapabilities1 = packet.readUInt16() else { throw SQLError.protocolError() }

        // int<1> server default collation
        guard let serverDefaultCollation = packet.readUInt8() else { throw SQLError.protocolError() }

        // int<2> status flags
        guard let statusFlags = packet.readUInt16() else { throw SQLError.protocolError() }

        // int<2> server capabilities (2nd part)
        guard let serverCapabilities2 = packet.readUInt16() else { throw SQLError.protocolError() }

        // int<1> plugin data length
        guard let pluginDataLength = packet.readUInt8() else { throw SQLError.protocolError() }

        // string<6> filler
        guard let filler = packet.readBytes(length: 6) else { throw SQLError.protocolError() }

        // int<4> server capabilities 3rd part . MariaDB specific flags /* MariaDB 10.2 or later */
        guard let serverCapabilities3 = packet.readUInt32() else { throw SQLError.protocolError() }

        // string<n> scramble 2nd part . Length = max(12, plugin data length - 9)
        guard let scramble2 = packet.readBytes(length: Int(max(12, pluginDataLength - 9))) else {
            throw SQLError.protocolError()
        }

        // string<1> reserved byte
        guard let reserved2 = packet.readUInt8() else { throw SQLError.protocolError() }

        // string<NUL> authentication plugin name
        let pluginName = packet.readCString()

        // Combine all the flags and make sure the ones we depend on are correct.
        let flags = MySQLCapabilities(rawValue: UInt64(serverCapabilities3) << 32 |
            UInt64(serverCapabilities2) << 16 | UInt64(serverCapabilities1))

        // Validate that we processed the entire packet and check flags that we depend on.
        // NOTE: We support COMPRESSion and SSL as well but do not require either.
        guard packet.body.readableBytes == 0 else { throw SQLError.protocolError() }
        guard flags.contains(.CONNECT_WITH_DB) else { throw SQLError.protocolError() }
        guard flags.contains(.CLIENT_PROTOCOL_41) else { throw SQLError.protocolError() }
        guard flags.contains(.SECURE_CONNECTION) else { throw SQLError.protocolError() }

        #if DEBUG
        print("************************************************************************")
        print("                   Protocol version: \(protocolVersion)")
        print("                     Server version: \(serverVersion)")
        print("                      Connection ID: \(connectionId)")
        print("                    Scramble part 1: \(scramble1)")
        print("                         Reserved 1: \(reserved1)")
        print("              Server capabilities 1: \(serverCapabilities1)")
        print("                   Server collation: \(serverDefaultCollation)")
        print("                       Status flags: \(statusFlags)")
        print("              Server capabilities 2: \(serverCapabilities2)")
        print("                 Plugin data length: \(pluginDataLength)")
        print("                             filler: \(filler)")
        print("              Server capabilities 3: \(serverCapabilities3)")
        print("                    Scramble part 2: \(scramble2)")
        print("                         Reserved 2: \(reserved2)")
        print("                        Plugin name: \(pluginName)")
        print("************************************")
        print("                       CLIENT_MYSQL: \(flags.contains(.CLIENT_MYSQL))")
        print("                         FOUND_ROWS: \(flags.contains(.FOUND_ROWS))")
        print("                    CONNECT_WITH_DB: \(flags.contains(.CONNECT_WITH_DB))")
        print("                           COMPRESS: \(flags.contains(.COMPRESS))")
        print("                        LOCAL_FILES: \(flags.contains(.LOCAL_FILES))")
        print("                       IGNORE_SPACE: \(flags.contains(.IGNORE_SPACE))")
        print("                 CLIENT_PROTOCOL_41: \(flags.contains(.CLIENT_PROTOCOL_41))")
        print("                 CLIENT_INTERACTIVE: \(flags.contains(.CLIENT_INTERACTIVE))")
        print("                                SSL: \(flags.contains(.SSL))")
        print("                       TRANSACTIONS: \(flags.contains(.TRANSACTIONS))")
        print("                  SECURE_CONNECTION: \(flags.contains(.SECURE_CONNECTION))")
        print("                   MULTI_STATEMENTS: \(flags.contains(.MULTI_STATEMENTS))")
        print("                      MULTI_RESULTS: \(flags.contains(.MULTI_RESULTS))")
        print("                   PS_MULTI_RESULTS: \(flags.contains(.PS_MULTI_RESULTS))")
        print("                        PLUGIN_AUTH: \(flags.contains(.PLUGIN_AUTH))")
        print("                      CONNECT_ATTRS: \(flags.contains(.CONNECT_ATTRS))")
        print("     PLUGIN_AUTH_LENENC_CLIENT_DATA: \(flags.contains(.PLUGIN_AUTH_LENENC_CLIENT_DATA))")
        print("               CLIENT_SESSION_TRACK: \(flags.contains(.CLIENT_SESSION_TRACK))")
        print("               CLIENT_DEPRECATE_EOF: \(flags.contains(.CLIENT_DEPRECATE_EOF))")
        print("  CLIENT_ZSTD_COMPRESSION_ALGORITHM: \(flags.contains(.CLIENT_ZSTD_COMPRESSION_ALGORITHM))")
        print("        CLIENT_CAPABILITY_EXTENSION: \(flags.contains(.CLIENT_CAPABILITY_EXTENSION))")
        print("            MARIADB_CLIENT_PROGRESS: \(flags.contains(.MARIADB_CLIENT_PROGRESS))")
        print("           MARIADB_CLIENT_COM_MULTI: \(flags.contains(.MARIADB_CLIENT_COM_MULTI))")
        print("MARIADB_CLIENT_STMT_BULK_OPERATIONS: \(flags.contains(.MARIADB_CLIENT_STMT_BULK_OPERATIONS))")
        print("************************************************************************")
        #endif

        // Create the Handshake Response Packet.
        // https://mariadb.com/kb/en/connection/#handshake-response-packet
        var response = MySQLPacket(sequenceNumber: packet.sequenceNumber &+ 1)

        var clientFlags = MySQLCapabilities(arrayLiteral: [.CONNECT_WITH_DB, .CLIENT_PROTOCOL_41, .SECURE_CONNECTION,
                                                           .PLUGIN_AUTH])

        // Enable compression if supported and not turned off.
//        if params["compress"] ?? "true" == "true" && flags.contains(.COMPRESS) {
//            clientFlags = clientFlags.union(.COMPRESS)
//        }

        // int<4> client capabilities
        response.writeUInt32(UInt32(clientFlags.rawValue & 0x00000000FFFFFFFF))

        // int<4> max packet size
        response.writeUInt32(MySQLPacket.maxPacketBodyLength)

        // int<1> client character collation
        // 224 - utf8mb4_unicode_ci
        response.writeUInt8(MySQLPacket.utf8mb4_unicode_ci)

        // string<19> reserved
        // if not (server_capabilities & CLIENT_MYSQL)
        //      int<4> extended client capabilities
        // else
        //      string<4> reserved
        response.writeBytes(Array<UInt8>(repeating: 0, count: 23))

        // string<NUL> username
        response.writeCString(params["user"]!)

        // else if (server_capabilities & CLIENT_SECURE_CONNECTION)
        //      int<1> length of authentication response
        //      string<fix> authentication response (length is indicated by previous field)
        //
        let passwordHash: [UInt8], saltedHash: [UInt8], authResponse: [UInt8]
        let seed = scramble1 + scramble2

        switch pluginName {
        case "mysql_native_password":
            // The password is encrypted with: SHA1( password ) ^ SHA1( seed + SHA1( SHA1( password ) ) )
            passwordHash = params["password"]!.bytes.sha1()
            saltedHash = (seed + passwordHash.sha1()).sha1()
/*
        case "caching_sha2_password":
            // Encryption is XOR(SHA256(password), SHA256(seed, SHA256(SHA256(password))))
            passwordHash = params["password"]!.bytes.sha256()
            saltedHash = (seed + passwordHash.sha256()).sha256()
*/
        default:
            throw SQLError.protocolError("Protocol error: Unsupported authentication plugin.")
        }

        authResponse = passwordHash.enumerated().map { $0.element ^ saltedHash[$0.offset] }
        response.writeUInt8(UInt8(authResponse.count))
        response.writeBytes(authResponse)

        // if (server_capabilities & CLIENT_CONNECT_WITH_DB)
        //      string<NUL> default database name
        response.writeCString(params["database"]!)

        // if (server_capabilities & CLIENT_PLUGIN_AUTH)
        //      string<NUL> authentication plugin name
        response.writeCString(pluginName)

        // Send the response.
        _ = context.writeAndFlush(wrapOutboundOut(response))
    }
}
*/
