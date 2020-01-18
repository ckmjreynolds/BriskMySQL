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
import SwiftCompression

/**
 The compressed MySQL/MariaDB packet has a 7 byte header + packet body.
 
     int<3> compress packet length
     int<1> compress sequence number
     int<3> uncompress packet length
     byte<n> compress body
     compress body contains one or many standard packets but can be compressed:
     one or many standard packets :
     int<3> packet length
     int<1> sequence number
     byte<n> packet body
 
 - See Also: [Compressed Packet](https://mariadb.com/kb/en/0-packet/#compressed-packet)
*/
internal struct MySQLCompressedPacket: MySQLPacket {
    static let headerLength = 7
    static let compressionThreshold = 50

    var header: [UInt8] = [UInt8](repeating: 0, count: Self.headerLength)
    var body: ByteBuffer = ByteBufferAllocator().buffer(capacity: 0)
}

extension MySQLCompressedPacket {
    init(packet: MySQLStandardPacket) {
        self.init(sequenceNumber: packet.sequenceNumber)

        self.body = packet.toByteBuffer()

        // Compress packets greater than MySQLCompressedPacket.compressionThreshold bytes.
        if body.readableBytes > MySQLCompressedPacket.compressionThreshold {
            self.uncompressedPacketLength = body.readableBytes

            let deflate = try? Deflate(windowBits: 15)
            let compressed = try? deflate?.process(Data(body.getBytes(at: 0, length: body.readableBytes)!))

            self.body.clear(); self.body.writeBytes(compressed!.bytes)
            self.packetLength = body.readableBytes
        } else {
            // This is an uncompressed, compressed packet.
            self.packetLength = body.readableBytes
            self.uncompressedPacketLength = 0
        }
    }

    mutating func decompressBody() -> ByteBuffer {
        // NO-OP if the data is not actually compressed.
        guard self.uncompressedPacketLength > 0 else { return self.body }

        let inflate = try? Inflate()
        let decompressed = try? inflate?.process(Data( body.getBytes(at: 0, length: body.readableBytes)!))

        self.body.clear(); self.body.writeBytes(decompressed!.bytes)
        return self.body
    }

    var uncompressedPacketLength: Int {
        get { Int.fromLittleEndianBytes(header.suffix(3), bitWidth: 24) }
        set { header.replaceSubrange(4...6, with: newValue.toLittleEndianBytes(bitWidth: 24)) }
    }
}
