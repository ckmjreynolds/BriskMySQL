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
import NIOSSL

/// Synonym for EventLoopFuture.
public typealias Future = EventLoopFuture

/// Public interface to MySQLConnection should be through SQLConnection.
public protocol SQLConnection {
    /// Creates a database connection and executes the closure, closing the connection once the closure completes.
    static func withDatabase<T>(to: URL, on: EventLoop, closure: @escaping (SQLConnection) -> Future<T>) -> Future<T>

    /// Creates a database connection on the provided EventLoop using the URL provided.
    static func connect(to: URL, on: EventLoop) -> Future<SQLConnection>

    /// Closes the database connection.
    func close() -> Future<Void>

    /// Returns true if the connection is still live..
    func isConnected() -> Future<Bool>
}

public extension SQLConnection {
    /// Creates a database connection and executes the closure, closing the connection once the closure completes.
    static func withDatabase<T>(to: URL, on: EventLoop, closure: @escaping (SQLConnection) -> Future<T>) -> Future<T> {
        self.connect(to: to, on: on).flatMap { conn -> Future<T> in
            closure(conn).map { result in
                _ = conn.close()
                return result
            }.flatMapError { error in
                conn.close().flatMapThrowing { throw error }
            }
        }
    }
}
