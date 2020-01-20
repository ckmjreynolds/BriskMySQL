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

/**
 The standard MySQL/MariaDB packet has a 4 byte header + packet body.
 
     int<3>  packet length
     int<1>  sequence number
     byte<n> packet body
 
 - See Also: [Standard Packet](https://mariadb.com/kb/en/0-packet/#standard-packet)
*/
internal struct MySQLStandardPacket: MySQLPacket {
    /// - See Also: [Protocol Data Types](https://mariadb.com/kb/en/protocol-data-types/)
    enum Encoding {
        case fixedLength(length: Int = -1)
        case lengthEncoded
        case endOfFile
        case nulTerminated
    }

    static let headerLength = 4

    // swiftlint:disable identifier_name
    static let OK_Packet: UInt8 = 0x00
    static let EOF_Packet: UInt8 = 0xFE
    static let ERR_Packet: UInt8 = 0xFF
    static let Fast_Auth_Packet: [UInt8] = [0x01, 0x04]

    static let COM_PING: UInt8 = 0x0E
    // swiftlint:enable identifier_name

    var header: [UInt8] = [UInt8](repeating: 0, count: Self.headerLength)
    var body: ByteBuffer = ByteBufferAllocator().buffer(capacity: 0)
}

// MARK: OK_Packet
// https://mariadb.com/kb/en/ok_packet/
extension MySQLStandardPacket {
    // int<1> 0x00 : OK_Packet header or (0xFE if CLIENT_DEPRECATE_EOF is set)
    // int<lenenc> affected rows
    // int<lenenc> last insert id
    // int<2> server status
    // int<2> warning count
    // if session_tracking_supported (see CLIENT_SESSION_TRACK)
    //      string<lenenc> info
    // if (status flags & SERVER_SESSION_STATE_CHANGED)
    //      string<lenenc> session state info
    //      string<lenenc> value of variable
    // else
    //      string<EOF> info

    /// Returns true if this is an OK packet and false otherwise.
    mutating func isOK() -> Bool {
        body.moveReaderIndex(to: 0); defer { body.moveReaderIndex(to: 0) }
        return readBytes(encoding: .fixedLength(length: 1))![0] == Self.OK_Packet
    }

    /// Returns the number of rows affected.
    mutating func affectedRows() -> Int {
        body.moveReaderIndex(to: 1)
        let affectedRows: UInt = readInteger(encoding: .lengthEncoded)!
        return Int(affectedRows)
    }

    /// Returns the last ID inserted.
    mutating func lastInsertID() -> Int {
        _ = affectedRows()
        let lastInsertID: UInt = readInteger(encoding: .lengthEncoded)!
        return Int(lastInsertID)
    }

    /// Returns a string representing the OK packet information.
    mutating func okInfo() -> String {
        let affectedRows = self.affectedRows()
        let lastInsertID = self.lastInsertID()
        let serverStatus: UInt16 = readInteger()!
        let warningCount: UInt16 = readInteger()!
        let info = readString(encoding: .endOfFile)!

        return "OK_Packet: rows: \(affectedRows) id: \(lastInsertID) status: \(serverStatus) " +
            "warnings: \(warningCount) info: " + info
    }
}

// MARK: ERR_Packet
// https://mariadb.com/kb/en/err_packet/
extension MySQLStandardPacket {
    // int<1> ERR_Packet header = 0xFF
    // int<2> error code. see error list
    // if (errorcode == 0xFFFF) /* progress reporting */
    //      int<1> stage
    //      int<1> max_stage
    //      int<3> progress
    //      string<lenenc> progress_info
    // else
    //      if (next byte = '#')
    //          string<1> sql state marker '#'
    //          string<5>sql state
    //          string<EOF> human-readable error message
    //      else
    //          string<EOF> human-readable error message

    /// Returns true if this is an error packet and false otherwise.
    mutating func isError() -> Bool {
        body.moveReaderIndex(to: 0); defer { body.moveReaderIndex(to: 0) }
        return readBytes(encoding: .fixedLength(length: 1))![0] == Self.ERR_Packet
    }

    /// Returns the error code.
    mutating func errorCode() -> Int {
        body.moveReaderIndex(to: 1)
        let errorCode: Int = readInteger(encoding: .fixedLength(length: 2))!
        return errorCode
    }

    /// Returns a string representing the error information.
    mutating func errorInfo() -> String {
        let errorCode = self.errorCode()
        var errorMessage = readString(encoding: .endOfFile)!

        if errorMessage.first == "#" {
            errorMessage = " (" + errorMessage.prefix(6).suffix(5) + "): " + errorMessage.suffix(errorMessage.count - 6)
        } else {
            errorMessage = ":" + errorMessage
        }

        return "ERROR " + String(errorCode) + errorMessage
    }
}

// MARK: "fast" authentication result".
// https://mariadb.com/kb/en/caching_sha2_password-authentication-plugin/#fast-authentication-result
extension MySQLStandardPacket {
    /// Returns true if this is "fast" authentication result meaning continue and send the password in plaintext.
    mutating func isFastAuthenticationResult() -> Bool {
        body.moveReaderIndex(to: 0); defer { body.moveReaderIndex(to: 0) }
        return readBytes(encoding: .fixedLength(length: 2))! == Self.Fast_Auth_Packet
    }
}

// MARK: Bytes.
extension MySQLStandardPacket {
    /// Read bytes from the packet body using the encoding requested.
    /// - Returns: The requested bytes or nil.
    mutating func readBytes(encoding: Encoding = .endOfFile) -> [UInt8]? {
        var bytes: [UInt8]? = [UInt8]()

        switch encoding {
        case .fixedLength(let length):
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-strings
            bytes = body.readBytes(length: length)

        case .lengthEncoded:
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-strings
            guard let length: UInt = readInteger(encoding: .lengthEncoded) else { return nil }
            bytes = readBytes(encoding: .fixedLength(length: Int(length)))

        case .endOfFile:
            // https://mariadb.com/kb/en/protocol-data-types/#end-of-file-length-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#end-of-file-length-strings
            bytes = readBytes(encoding: .fixedLength(length: body.readableBytes))

        case .nulTerminated:
            // https://mariadb.com/kb/en/protocol-data-types/#null-terminated-strings
            while let byte = readBytes(encoding: .fixedLength(length: 1))?.first, byte != 0 { bytes?.append(byte) }
        }

        return bytes
    }

    /// Write bytes to the packet body using the encoding requested.
    @discardableResult
    mutating func writeBytes(_ bytes: [UInt8], encoding: Encoding = .endOfFile) -> Int {
        var count = Int.zero

        switch encoding {
        case .fixedLength(let length):
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-strings
            count += body.writeBytes(bytes.prefix(min(max(length, 0), bytes.count)))
            packetLength += count

        case .lengthEncoded:
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-strings
            count += writeInteger(UInt(bytes.count), encoding: .lengthEncoded)
            count += writeBytes(bytes, encoding: .fixedLength(length: bytes.count))

        case .endOfFile:
            // https://mariadb.com/kb/en/protocol-data-types/#end-of-file-length-bytes
            // https://mariadb.com/kb/en/protocol-data-types/#end-of-file-length-strings
            count += writeBytes(bytes, encoding: .fixedLength(length: bytes.count))

        case .nulTerminated:
            // https://mariadb.com/kb/en/protocol-data-types/#null-terminated-strings
            count += writeBytes(bytes, encoding: .fixedLength(length: bytes.count))
            count += writeBytes([0], encoding: .fixedLength(length: 1))
        }

        return count
    }
}

// MARK: Integers
extension MySQLStandardPacket {
    /// Read integer from the packet body using the encoding requested.
    /// - Returns: The requested integer or nil.
    mutating func readInteger<T>(encoding: Encoding = .fixedLength()) -> T? where T: FixedWidthInteger {
        var value: T?

        switch encoding {
        case .fixedLength(var length):
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-integers
            if length == -1 { length = T.bitWidth / 8 }
            precondition((1...T.bitWidth / 8).contains(length))
            guard let bytes = readBytes(encoding: .fixedLength(length: length)) else { return nil }
            value = T.fromLittleEndianBytes(bytes, bitWidth: length * 8)

        case .lengthEncoded:
            // Length encoded integers
            // The notation is "int<lenenc>" An integer which depending on its value is represented by n bytes.
            //
            // The first byte represents the size of the integer:
            //
            // If the value of first byte is
            //
            // < 0xFB - Integer value is this 1 byte integer
            // 0xFB - NULL value
            // 0xFC - Integer value is encoded in the next 2 bytes (3 bytes total)
            // 0xFD - Integer value is encoded in the next 3 bytes (4 bytes total)
            // 0xFE - Integer value is encoded in the next 8 bytes (9 bytes total)
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-integers
            precondition(!T.isSigned && T.bitWidth >= 64)
            value = readInteger(encoding: .fixedLength(length: 1))

            switch value {
            case 0xFB:
                value = nil
            case 0xFC:
                value = readInteger(encoding: .fixedLength(length: 2))
            case 0xFD:
                value = readInteger(encoding: .fixedLength(length: 3))
            case 0xFE:
                value = readInteger(encoding: .fixedLength(length: 8))
            default:
                break
            }

        default:
            value = readInteger(encoding: .fixedLength(length: T.bitWidth / 8))
        }

        return value
    }

    /// Write integer to the packet body using the encoding requested.
    @discardableResult
    mutating func writeInteger<T>(_ value: T?, encoding: Encoding = .fixedLength()) -> Int where T: FixedWidthInteger {
        var count = Int.zero

        switch encoding {
        case .fixedLength(var length):
            // https://mariadb.com/kb/en/protocol-data-types/#fixed-length-integers
            if length == -1 { length = T.bitWidth / 8 }
            precondition((1...T.bitWidth / 8).contains(length))
            precondition(value != nil)
            count += writeBytes(value!.toLittleEndianBytes(bitWidth: length * 8))

        case .lengthEncoded:
            // Length encoded integers
            // The notation is "int<lenenc>" An integer which depending on its value is represented by n bytes.
            //
            // The first byte represents the size of the integer:
            //
            // If the value of first byte is
            //
            // < 0xFB - Integer value is this 1 byte integer
            // 0xFB - NULL value
            // 0xFC - Integer value is encoded in the next 2 bytes (3 bytes total)
            // 0xFD - Integer value is encoded in the next 3 bytes (4 bytes total)
            // 0xFE - Integer value is encoded in the next 8 bytes (9 bytes total)
            // https://mariadb.com/kb/en/protocol-data-types/#length-encoded-integers
            precondition(value ?? 0 >= 0)
            guard let value = value else { return writeInteger(0xFB, encoding: .fixedLength(length: 1)) }

            switch value {
            case 0..<0xFB:
                count += writeInteger(value, encoding: .fixedLength(length: 1))
            case 0xFB...0xFFFF:
                count += writeInteger(0xFC, encoding: .fixedLength(length: 1))
                count += writeInteger(value, encoding: .fixedLength(length: 2))
            case 0x10000...0xFFFFFF:
                count += writeInteger(0xFD, encoding: .fixedLength(length: 1))
                count += writeInteger(value, encoding: .fixedLength(length: 3))
            default:
                count += writeInteger(0xFE, encoding: .fixedLength(length: 1))
                count += writeInteger(value, encoding: .fixedLength(length: 8))
            }

        default:
            count += writeInteger(value, encoding: .fixedLength(length: T.bitWidth / 8))
        }

        return count
    }
}

// MARK: Strings.
extension MySQLStandardPacket {
    /// Read a string from the packet body using the encoding requested.
    /// - Returns: The requested string or nil.
    mutating func readString(encoding: Encoding = .nulTerminated) -> String? {
        guard let bytes = readBytes(encoding: encoding) else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }

    /// Write bytes to the packet body using the encoding requested.
    @discardableResult
    mutating func writeString(_ string: String, encoding: Encoding = .nulTerminated) -> Int {
        writeBytes([UInt8](string.data(using: .utf8)!), encoding: encoding)
    }
}
