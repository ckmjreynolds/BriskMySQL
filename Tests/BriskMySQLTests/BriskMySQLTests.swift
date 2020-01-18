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
import XCTest
import NIO
@testable import BriskMySQL

final class BriskMySQLTests: XCTestCase {
    let dbhost = ProcessInfo.processInfo.environment["DB_HOST"] ?? "127.0.0.1"
    let dbPassword = ProcessInfo.processInfo.environment["DB_PASSWORD"] ?? "password"

    var testMatrix: [String: URL] = [:]
    var eventLoopGroup: MultiThreadedEventLoopGroup!

    override func setUp() {
        testMatrix = [
            "proxysql:latest": URL(string: "mysql://test_user:" + dbPassword + "@" + dbhost + ":6033/testdb")!,
            "mariadb:latest": URL(string: "mysql://test_user:" + dbPassword + "@" + dbhost + ":3301/testdb")!,
            "mysql:latest": URL(string: "mysql://test_user:" + dbPassword + "@" + dbhost + ":3306/testdb")!,
            "error:password": URL(string: "mysql://test_user:passwor@" + dbhost + ":3306/tempdb")!
        ]

        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    func testConnection() {
        let eventLoop = eventLoopGroup.next()
        for server in testMatrix {
            do {
                try MySQLConnection.withConnection(to: server.value, on: eventLoop) { conn in
                    conn.isConnected()
                }.map { result in
                    if !server.key.contains("error:") {
                        XCTAssert(result)
                    } else {
                        XCTFail("This should have failed.")
                    }
                }.wait()
            } catch {
                if !server.key.contains("error:") {
                    XCTFail(server.key + " - ERROR: " + error.localizedDescription)
                } else {
                    switch server.key.split(separator: ":")[1] {
                    case "password":
                        XCTAssert(error.localizedDescription.contains("ERROR 1045"))
                    default:
                        XCTFail("Unexpected error message.")
                    }
                }
            }
        }
    }

    static var allTests = [
        ("testConnection", testConnection)
    ]
}
