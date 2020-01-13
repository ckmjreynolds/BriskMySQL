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
import XCTest
import NIO
@testable import BriskMySQL

final class MySQLPacketTests: XCTestCase {
    // swiftlint:disable identifier_name
    static let COM_PING: [UInt8] = [0x01, 0x00, 0x00, 0x42, 0x0E]
    // swiftlint:enable identifier_name

    func testByteBufferConversions() throws {
        let testVector = MySQLPacketTests.COM_PING

        // Create the buffer from the test vector.
        var buffer = ByteBufferAllocator().buffer(capacity: MySQLPacketTests.COM_PING.count)
        buffer.writeBytes(testVector)

        // Test ByteBuffer->MySQLPacket.
        guard let packet = MySQLStandardPacket.fromByteBuffer(buffer: &buffer) else {
            XCTFail("MySQLPacket.fromByteBuffer FAILED!")
            return
        }

        // Test that our debug output appears valid as well.
        XCTAssert(packet.debugDescription.contains("01 00 00 42 0e"), "MySQLPacket.debugDescription FAILED!")

        // Test MySQLPacket->ButeBuffer
        buffer = packet.toByteBuffer()
        let result = buffer.getBytes(at: 0, length: MySQLPacketTests.COM_PING.count)

        XCTAssert(result == testVector, "MySQLPacket.toByteBuffer FAILED!")
    }

    func testInvalidByteBufferConversions() throws {
        let testMatrix = [MySQLPacketTests.COM_PING.prefix(3), MySQLPacketTests.COM_PING.prefix(4)]

        for testVector in testMatrix {
            // Create the buffer from the test vector.
            var buffer = ByteBufferAllocator().buffer(capacity: MySQLPacketTests.COM_PING.count)
            buffer.writeBytes(testVector)

            // Test ByteBuffer->MySQLPacket.
            XCTAssertNil(MySQLStandardPacket.fromByteBuffer(buffer: &buffer), "MySQLPacket.fromByteBuffer FAILED!")
        }
    }

    func testPacketLength() throws {
        let testVector = Int.random(in: (0x0...0xFFFFFF))

        var packet = MySQLStandardPacket()
        packet.packetLength = testVector

        XCTAssert(packet.packetLength == testVector, "MySQLPacket.packetLength FAILED!")
    }

    func testSequenceNumber() throws {
        let testVector = Int.random(in: (0x0...0xFF))

        var packet = MySQLStandardPacket()
        packet.sequenceNumber = testVector

        XCTAssert(packet.sequenceNumber == testVector, "MySQLPacket.sequenceNumber FAILED!")
    }

    static var allTests = [
        ("testByteBufferConversions", testByteBufferConversions),
        ("testInvalidByteBufferConversions", testInvalidByteBufferConversions),
        ("testPacketLength", testPacketLength),
        ("testSequenceNumber", testSequenceNumber)
    ]
}
