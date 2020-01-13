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

final class MySQLStandardPacketTests: XCTestCase {
    func testFixedLengthBytes() {
        let testVector: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10]
        var packet = MySQLStandardPacket()

        packet.writeBytes(testVector)
        packet.body.moveReaderIndex(to: 0)
        let result = packet.readBytes(length: testVector.count)

        XCTAssert(result == testVector, "MySQLStandardPacket.writeBytes/readBytes FAILED!")
    }

    func testFixedWidthInteger() {
        let testVector = Int.random(in: Int.min...Int.max)
        var packet = MySQLStandardPacket()

        packet.writeInteger(testVector)
        packet.body.moveReaderIndex(to: 0)

        guard let result: Int = packet.readInteger() else {
            XCTFail("MySQLStandardPacket.writeInteger/readInteger FAILED!")
            return
        }

        XCTAssert(result == testVector, "MySQLStandardPacket.writeInteger/readInteger FAILED!")
    }

    func testLengthEncodedInteger() {
        let testMatrix = [nil, UInt.random(in: 0x00...0xFA), UInt.random(in: 0xFB...0xFFFF),
                          UInt.random(in: 0x10000...0xFFFFFF), UInt.random(in: 0x1000000...UInt.max)]

        for testVector in testMatrix {
            var packet = MySQLStandardPacket()

            packet.writeLenEncInteger(testVector)
            packet.body.moveReaderIndex(to: 0)
            let result: UInt? = packet.readLenEncInteger()

            XCTAssert(result == testVector, "MySQLStandardPacket.writeLenEncInteger/readLenEncInteger FAILED!")
        }
    }

    func testLengthEncodedBytes() {
        let testVector: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10]
        var packet = MySQLStandardPacket()

        packet.writeLenEncBytes(testVector)
        packet.body.moveReaderIndex(to: 0)
        let result = packet.readLenEncBytes()

        XCTAssert(result == testVector, "MySQLStandardPacket.writeLenEncBytes/readLenEncBytes FAILED!")
    }

    func testEndOfFileLengthBytes() {
        let testVector: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10]
        var packet = MySQLStandardPacket()

        packet.writeBytes(testVector)
        packet.body.moveReaderIndex(to: 0)
        let result = packet.readBytes()

        XCTAssert(result == testVector, "MySQLStandardPacket.readBytes FAILED!")
    }

    func testFixedLengthString() {
        let testVector = "Now is the time for all good men to come to the aid of their country."
        var packet = MySQLStandardPacket()

        packet.writeString(testVector)
        packet.body.moveReaderIndex(to: 0)

        guard let result = packet.readString(length: testVector.utf8.count) else {
            XCTFail("MySQLStandardPacket.writeString/readString FAILED!")
            return
        }

        XCTAssert(result == testVector, "MySQLStandardPacket.writeBytes/readBytes FAILED!")
    }

    func testCString() {
        let testVector = "Now is the time for all good men to come to the aid of their country."
        var packet = MySQLStandardPacket()

        packet.writeCString(testVector)
        packet.body.moveReaderIndex(to: 0)

        XCTAssert(packet.readCString() == testVector, "MySQLStandardPacket.writeCString/readCString FAILED!")
    }

    func testLengthEncodedStrings() {
        let testVector = "Now is the time for all good men to come to the aid of their country."
        var packet = MySQLStandardPacket()

        packet.writeLenEncString(testVector)
        packet.body.moveReaderIndex(to: 0)

        XCTAssert(packet.readLenEncString() == testVector, "MySQLStandardPacket.write/readLenEncString FAILED!")
    }

    func testInvalidInputs() {
        var packet = MySQLStandardPacket()
        var result: UInt?

        result = packet.readInteger(); XCTAssertNil(result, "MySQLStandardPacket.readInteger FAILED!")
        result = packet.readLenEncInteger(); XCTAssertNil(result, "MySQLStandardPacket.readLenEncInteger FAILED!")

        XCTAssertNil(packet.readLenEncBytes(), "MySQLStandardPacket.readLenEncBytes FAILED!")
        XCTAssertNil(packet.readString(length: 1), "MySQLStandardPacket.readString FAILED!")
        XCTAssertNil(packet.readLenEncString(), "MySQLStandardPacket.readLenEncString FAILED!")
    }
}
