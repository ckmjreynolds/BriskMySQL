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

    func testByteBufferConversions() {
        var buffer = ByteBufferAllocator().buffer(capacity: MySQLPacketTests.COM_PING.count)
        buffer.writeBytes(MySQLPacketTests.COM_PING)

        let packet = MySQLStandardPacket(buffer: &buffer)
        XCTAssertNotNil(packet, #function + " MySQLPacket(bufffer:) FAILED!")
        XCTAssert(packet?.packetLength == 0x01, #function + " packetLength FAILED!")
        XCTAssert(packet?.sequenceNumber == 0x42, #function + " sequenceNumber FAILED!")
        XCTAssert(packet?.debugDescription.contains("01 00 00 42 0e") ?? false, #function + " debugDescription FAILED!")

        let testResult = packet?.toByteBuffer().getBytes(at: 0, length: MySQLPacketTests.COM_PING.count)
        XCTAssert(testResult == MySQLPacketTests.COM_PING, #function + " toByteBuffer FAILED!")

        // Corrupt the packet length and attempt to parse the packet.
        buffer.writeBytes(MySQLPacketTests.COM_PING.reversed())
        XCTAssertNil(MySQLStandardPacket(buffer: &buffer), " MySQLPacket(bufffer:) FAILED!")
        buffer.clear()

        // Corrupt the packet header and attempt to parse the packet.
        buffer.writeBytes([UInt8](repeating: 0, count: MySQLStandardPacket.headerLength - 1))
        XCTAssertNil(MySQLStandardPacket(buffer: &buffer), " MySQLPacket(bufffer:) FAILED!")
        buffer.clear()
    }
}
