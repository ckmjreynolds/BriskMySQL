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
    /// Packets have a maxium payload size.
    static var maxPacketLength: Int { get }

    /// Packets have a four (standard) or seven (compressed) byte header.
    static var headerLength: Int { get }
    var header: [UInt8] { get set }

    /// Packet body of length packetLength bytes.
    var body: ByteBuffer { get set }

    /// int<3> - packet length
    var packetLength: Int { get set }

    /// int<1> - sequence number
    var sequenceNumber: Int { get set }

    /// Initialize an empty packet with the given sequence number.
    init(sequenceNumber: Int)

    /// Create a new MySQLPacket from a ByteBuffer or fail.
    init?(buffer: inout ByteBuffer)
    init()

    /// Create a new ByteBuffer representing this MySQLPacket.
    func toByteBuffer() -> ByteBuffer
}

// MARK: Default implementation of protocol requirements.
extension MySQLPacket {
    init(sequenceNumber: Int) { self.init(); self.sequenceNumber = sequenceNumber }

    static var maxPacketLength: Int { 0xFFFFFF }

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
    init?(buffer: inout ByteBuffer) {
        self.init(sequenceNumber: 0)

        guard buffer.readableBytes >= Self.headerLength else { return nil }
        self.header = buffer.readBytes(length: Self.headerLength)!

        guard buffer.readableBytes >= packetLength else { return nil }
        body = buffer.readSlice(length: packetLength)!
    }

    func toByteBuffer() -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: Self.headerLength + packetLength)
        var body = self.body.getSlice(at: 0, length: packetLength)!
        buffer.writeBytes(header)
        buffer.writeBuffer(&body)

        return buffer
    }
}

// MARK: CustomDebugStringConvertible
extension MySQLPacket {
    var debugDescription: String { toByteBuffer().debugDescription }
}
