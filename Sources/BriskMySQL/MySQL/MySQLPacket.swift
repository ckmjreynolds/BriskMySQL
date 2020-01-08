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

/**
 https://mariadb.com/kb/en/0-packet/
 
 The standard MySQL/MariaDB packet has a 4 bytes header + packet body.

int<3> packet length
int<1> sequence number
byte<n> packet body
Packet length is the length of the packet body. Packet length size cannot be more than 3 bytes length value. The actual length of the packet is calculated as from the 3 bytes as length = byte[0] + (byte[1]<<8) + (byte[2]<<16). The maximum size of a packet (with all 3 bytes 0xff) is 16777215 , or 2^24-1 or 0xffffff, or 16MB-1byte.

The sequence number indicates the exchange number when an exchange demands different exchanges. Whenever the client sends a query, the sequence number is set to 0 initially, and is incremented if clients need to split packets. In more complex situations, when the client and server exchange several packets, e.g authentication handshake, the rule of thumb for clients is to set sequence nr = (last seq.nr from received server packet + 1)

Example: Sending a COM_PING packet COM_PING body has only one byte (0x10):

01 00 00 00 10
The server will then return an OK_Packet response with a sequence number of 1.

Packet splitting
As mentioned, the packet length is 3 bytes making a maximum size of (2^24 -1) bytes or 16Mbytes-1byte. But the protocol allows sending and receiving larger data. For those cases, the client can send many packets for the same data, incrementing the sequence number for each packet.

The principle is to split data by chunks of 16MBytes. When the server receives a packet with 0xffffff length, it will continue to read the next packet. In case of a length of exactly 16MBytes, an empty packet must terminate the sequence.
 */
internal struct MySQLPacket: CustomDebugStringConvertible {
    // https://mariadb.com/kb/en/0-packet/
    private static let packetHeaderLength: Int = 4
    static let maxPacketBodyLength: UInt32 = 0xFFFFFF

    // 224 - utf8mb4_unicode_ci
    static let utf8mb4_unicode_ci: UInt8 = 224

    private(set) var packetLength: Int
    private(set) var sequenceNumber: UInt8

    var body: ByteBuffer

    init(sequenceNumber: UInt8) {
        self.body = ByteBufferAllocator().buffer(capacity: 0)
        self.sequenceNumber = sequenceNumber
        self.packetLength = 0
    }

    init?(buffer: inout ByteBuffer) {
        guard buffer.readableBytes >= MySQLPacket.packetHeaderLength else { return nil }

        packetLength = Int(buffer.getInteger(at: buffer.readerIndex, endianness: .little, as: UInt32.self)!)
        sequenceNumber = UInt8((packetLength & 0xFF000000) >> 24)
        packetLength &= 0x00FFFFFF

        guard buffer.readableBytes >= MySQLPacket.packetHeaderLength + packetLength else { return nil }

        _ = buffer.readBytes(length: MySQLPacket.packetHeaderLength)
        body = buffer.readSlice(length: packetLength)!
    }

    mutating func readUInt8() -> UInt8? { body.readInteger(endianness: .little, as: UInt8.self) }
    mutating func readUInt16() -> UInt16? { body.readInteger(endianness: .little, as: UInt16.self) }
    mutating func readUInt32() -> UInt32? { body.readInteger(endianness: .little, as: UInt32.self) }
    mutating func readBytes(length: Int) -> [UInt8]? { body.readBytes(length: length) }
    mutating func readCString() -> String {
        var ret = ""; while let chr = readUInt8(), chr != 0 { ret += String(UnicodeScalar(chr)) }
        return ret
    }

    mutating func writeUInt8(_ value: UInt8) {
        body.writeInteger(value, endianness: .little, as: UInt8.self)
        packetLength += 1
    }

    mutating func writeUInt32(_ value: UInt32) {
        body.writeInteger(value, endianness: .little, as: UInt32.self)
        packetLength += 4
    }

    mutating func writeBytes(_ bytes: [UInt8]) {
        body.writeBytes(bytes)
        packetLength += bytes.count
    }

    mutating func writeCString(_ string: String) {
        body.writeString(string)
        body.writeInteger(0, endianness: .little, as: UInt8.self)
        packetLength += string.utf8.count + 1
    }

    var debugDescription: String {
        return "LEN: \(packetLength), SEQ: \(sequenceNumber), BODY: \(body.debugDescription)"
    }
}
