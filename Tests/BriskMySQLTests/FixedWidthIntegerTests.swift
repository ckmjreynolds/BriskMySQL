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

final class FixedWidthIntegerTests: XCTestCase {
    func testToLittleEndianBytes() throws {
        let testVector: UInt64 = 0x0807060504030201
        let expectedResult: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        let result = testVector.toLittleEndianBytes(bitWidth: 64)

        XCTAssert(result == expectedResult, "FixedWidthInteger.toLittleEndianBytes FAILED!")
    }

    func testFromLittleEndianBytes() throws {
        let testVector: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10]
        let expectedResult: UInt64 = 0x0807060504030201
        let result = UInt64.fromLittleEndianBytes(testVector, bitWidth: 64)

        XCTAssert(result == expectedResult, "FixedWidthInteger.fromLittleEndianBytes FAILED!")
    }

    static var allTests = [
        ("testToLittleEndianBytes", testToLittleEndianBytes),
        ("testFromLittleEndianBytes", testFromLittleEndianBytes)
    ]
}
