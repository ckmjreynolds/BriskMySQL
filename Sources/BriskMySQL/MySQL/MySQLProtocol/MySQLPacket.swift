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
 The standard **and** compressed MySQL/MariaDB packets can be considered to share a common, initial 4 byte header.
 
     int<3>  packet length
     int<1>  sequence number
     byte<n> packet body
 
 - See Also: [Packet](https://mariadb.com/kb/en/0-packet)
*/
internal protocol MySQLPacket: CustomDebugStringConvertible {
    static var headerLength: Int { get }

    var header: [UInt8] { get set }
    var body: ByteBuffer { get set }

    /// int<3> - packet length
    var packetLength: Int { get set }

    /// int<1> - sequence number
    var sequenceNumber: Int { get set }

    /// Default initializer is required by default implementations provided below.
    init()
}

// MARK: Default implementation of protocol requirements.
extension MySQLPacket {
    var packetLength: Int {
        get { Int.fromLittleEndianBytes(header, bitWidth: 24) }
        set { header.replaceSubrange(0...2, with: newValue.toLittleEndianBytes(bitWidth: 24)) }
    }

    var sequenceNumber: Int {
        get { Int(header[3]) }
        set { header[3] = UInt8(truncatingIfNeeded: newValue) }
    }
}

// MARK: ByteBuffer Conversions.
extension MySQLPacket {
    /// Create a new MySQLPacket from a ByteBuffer or return nil if unable.
    static func fromByteBuffer(buffer: inout ByteBuffer) -> Self? {
        var packet = Self()

        guard buffer.readableBytes >= Self.headerLength else { return nil }
        packet.header = buffer.readBytes(length: Self.headerLength)!

        guard buffer.readableBytes >= packet.packetLength else { return nil }
        packet.body = buffer.readSlice(length: packet.packetLength)!

        return packet
    }

    /// Create a new ByteBuffer representing this MySQLPacket.
    func toByteBuffer() -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: Self.headerLength + packetLength)

        buffer.writeBytes(header)
        buffer.writeBytes(body.getBytes(at: 0, length: packetLength)!)

        return buffer
    }
}

// MARK: CustomDebugStringConvertible
extension MySQLPacket {
    var debugDescription: String { toByteBuffer().debugDescription }
}

