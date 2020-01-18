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
    func testBytes() {
        var packet = MySQLStandardPacket()
        let testVector: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        packet.writeBytes(testVector, encoding: .fixedLength(length: testVector.count))
        packet.writeBytes(testVector, encoding: .lengthEncoded)
        packet.writeBytes(testVector, encoding: .nulTerminated)
        packet.writeBytes(testVector, encoding: .endOfFile)

        packet.body.moveReaderIndex(to: 0)

        XCTAssert(testVector == packet.readBytes(encoding: .fixedLength(length: testVector.count)))
        XCTAssert(testVector == packet.readBytes(encoding: .lengthEncoded))
        XCTAssert(testVector == packet.readBytes(encoding: .nulTerminated))
        XCTAssert(testVector == packet.readBytes(encoding: .endOfFile))
        XCTAssertNil(packet.readBytes(encoding: .lengthEncoded))
    }

    func testStrings() {
        var packet = MySQLStandardPacket()
        let testVector = "Now is the time for all good men to come to the aid of their country."

        packet.writeString(testVector, encoding: .fixedLength(length: testVector.count))
        packet.writeString(testVector, encoding: .lengthEncoded)
        packet.writeString(testVector, encoding: .nulTerminated)
        packet.writeString(testVector, encoding: .endOfFile)

        packet.body.moveReaderIndex(to: 0)

        XCTAssert(testVector == packet.readString(encoding: .fixedLength(length: testVector.count)))
        XCTAssert(testVector == packet.readString(encoding: .lengthEncoded))
        XCTAssert(testVector == packet.readString(encoding: .nulTerminated))
        XCTAssert(testVector == packet.readString(encoding: .endOfFile))
        XCTAssertNil(packet.readString(encoding: .lengthEncoded))
    }

    func testIntegers() {
        var packet = MySQLStandardPacket()
        let testMatrix: [UInt?] = [
            UInt.random(in: UInt.min...UInt.max),           // .fixedLength(length: 8)
            nil,                                            // .lengthEncoded
            UInt.random(in: 0x00...0xFA),                   // .lengthEncoded
            UInt.random(in: 0xFB...0xFFFF),                 // .lengthEncoded
            UInt.random(in: 0x10000...0xFFFFFF),            // .lengthEncoded
            UInt.random(in: 0x1000000...0xFFFFFFFFFFFFFFF), // .lengthEncoded
            UInt.random(in: UInt.min...UInt.max)            // .endOfFile
        ]

        packet.writeInteger(testMatrix[0], encoding: .fixedLength(length: 8))
        packet.writeInteger(testMatrix[1], encoding: .lengthEncoded)
        packet.writeInteger(testMatrix[2], encoding: .lengthEncoded)
        packet.writeInteger(testMatrix[3], encoding: .lengthEncoded)
        packet.writeInteger(testMatrix[4], encoding: .lengthEncoded)
        packet.writeInteger(testMatrix[5], encoding: .lengthEncoded)
        packet.writeInteger(testMatrix[6], encoding: .endOfFile)

        packet.body.moveReaderIndex(to: 0)

        XCTAssert(testMatrix[0] == packet.readInteger(encoding: .fixedLength(length: 8)))
        XCTAssert(testMatrix[1] == packet.readInteger(encoding: .lengthEncoded))
        XCTAssert(testMatrix[2] == packet.readInteger(encoding: .lengthEncoded))
        XCTAssert(testMatrix[3] == packet.readInteger(encoding: .lengthEncoded))
        XCTAssert(testMatrix[4] == packet.readInteger(encoding: .lengthEncoded))
        XCTAssert(testMatrix[5] == packet.readInteger(encoding: .lengthEncoded))
        XCTAssert(testMatrix[6] == packet.readInteger(encoding: .endOfFile))
    }
}
