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
 The standard MySQL/MariaDB packet has a 4 bytes header + packet body.
 
     int<3>  packet length
     int<1>  sequence number
     byte<n> packet body
 
 - See Also: [Standard Packet](https://mariadb.com/kb/en/0-packet/#standard-packet)
*/
internal struct MySQLStandardPacket: MySQLPacket {
    static let headerLength = 4

    var header: [UInt8]
    var body: ByteBuffer

    /// Initialize an empty packet with the given sequence number.
    init(sequenceNumber: Int) {
        self.header = [UInt8](repeating: 0, count: MySQLStandardPacket.headerLength)
        self.body = ByteBufferAllocator().buffer(capacity: 0)
        self.sequenceNumber = sequenceNumber
    }

    init() { self.init(sequenceNumber: 0) }
}

// MARK: Fixed length bytes.
// https://mariadb.com/kb/en/protocol-data-types/#fixed-length-bytes
extension MySQLStandardPacket {
    mutating func readBytes(length: Int) -> [UInt8]? { body.readBytes(length: length) }
    mutating func writeBytes(_ bytes: [UInt8]) { defer { packetLength += bytes.count }; body.writeBytes(bytes) }
}

// MARK: Fixed length integers
// https://mariadb.com/kb/en/protocol-data-types/#fixed-length-integers
extension MySQLStandardPacket {
    mutating func readInteger<T>(bitWidth: Int = T.bitWidth) -> T? where T: FixedWidthInteger {
        guard let bytes = readBytes(length: bitWidth / 8) else { return nil }
        return T.fromLittleEndianBytes(bytes, bitWidth: bitWidth)
    }

    mutating func writeInteger<T>(_ value: T, bitWidth: Int = T.bitWidth) where T: FixedWidthInteger {
        writeBytes(value.toLittleEndianBytes(bitWidth: bitWidth))
    }
}

// MARK: Length encoded integers
// https://mariadb.com/kb/en/protocol-data-types/#length-encoded-integers
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
extension MySQLStandardPacket {
    mutating func readLenEncInteger<T>() -> T? where T: FixedWidthInteger, T: UnsignedInteger {
        guard let ret: T = readInteger(bitWidth: 1 * 8) else { return nil }

        switch ret {
        case 0xFB:
            return nil
        case 0xFC:
            return readInteger(bitWidth: 2 * 8)
        case 0xFD:
            return readInteger(bitWidth: 3 * 8)
        case 0xFE:
            return readInteger(bitWidth: 8 * 8)
        default:
            return ret
        }
    }

    mutating func writeLenEncInteger<T>(_ value: T?) where T: FixedWidthInteger, T: UnsignedInteger {
        guard let value = value else { return writeInteger(0xFB, bitWidth: 1 * 8) }
        switch value {
        case 0..<0xFB:
            writeInteger(value, bitWidth: 1 * 8)
        case 0xFB...0xFFFF:
            writeInteger(0xFC, bitWidth: 1 * 8)
            writeInteger(value, bitWidth: 2 * 8)
        case 0x10000...0xFFFFFF:
            writeInteger(0xFD, bitWidth: 1 * 8)
            writeInteger(value, bitWidth: 3 * 8)
        default:
            writeInteger(0xFE, bitWidth: 1 * 8)
            writeInteger(value, bitWidth: 8 * 8)
        }
    }
}

// MARK: Length encoded bytes
// https://mariadb.com/kb/en/protocol-data-types/#length-encoded-bytes
extension MySQLStandardPacket {
    mutating func readLenEncBytes() -> [UInt8]? {
        guard let length: UInt = readLenEncInteger() else { return nil }
        return readBytes(length: Int(length))
    }

    mutating func writeLenEncBytes(_ bytes: [UInt8]) {
        writeLenEncInteger(UInt(bytes.count))
        writeBytes(bytes)
    }
}

// MARK: End of file length bytes
// https://mariadb.com/kb/en/protocol-data-types/#end-of-file-length-bytes
extension MySQLStandardPacket {
    mutating func readBytes() -> [UInt8]? { readBytes(length: body.readableBytes) }
}

// MARK: Fixed-length strings
// https://mariadb.com/kb/en/protocol-data-types/#fixed-length-strings
extension MySQLStandardPacket {
    mutating func readString(length: Int) -> String? {
        guard let bytes = readBytes(length: length) else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }

    mutating func writeString(_ string: String) {
        writeBytes(Array(string.data(using: .utf8)!))
    }
}

// MARK: Null-terminated strings
// https://mariadb.com/kb/en/protocol-data-types/#null-terminated-strings
extension MySQLStandardPacket {
    mutating func readCString() -> String {
        var ret = ""

        while let chr: UInt8 = readInteger(bitWidth: 8), chr != 0 {
            ret += String(UnicodeScalar(chr))
        }

        return ret
    }

    mutating func writeCString(_ string: String) {
        writeString(string + "\0")
    }
}

// MARK: Length-encoded strings
// https://mariadb.com/kb/en/protocol-data-types/#length-encoded-strings
extension MySQLStandardPacket {
    mutating func readLenEncString() -> String? {
        guard let bytes = readLenEncBytes() else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }

    mutating func writeLenEncString(_ string: String) {
        writeLenEncBytes(Array(string.data(using: .utf8)!))
    }
}
