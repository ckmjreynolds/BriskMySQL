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
//  2020-01-19  CDR     Initial Version
// *********************************************************************************************************************
import NIO

class TimedPromise<T> {
    let promise: EventLoopPromise<T>
    var terminator: Scheduled<Void>?

    init(eventLoop: EventLoop, timeout: Int, file: StaticString = #file, line: UInt = #line) {
        precondition(timeout > 0)

        // Create the promise.
        promise = eventLoop.makePromise(of: T.self)

        // ... and schedule its termination.
        terminator = eventLoop.scheduleTask(in: .seconds(Int64(timeout))) {
            self.promise.fail(SQLError.timeout)
        }
    }

    func succeed(_ value: T) { terminator?.cancel(); promise.succeed(value) }
    func fail(_ error: Error) { terminator?.cancel(); promise.fail(error) }
    var futureResult: EventLoopFuture<T> { promise.futureResult }
}

extension EventLoop {
    /// Creates and returns a new `EventLoopPromise` that will be automatically failed at timeout seconds..
    func makePromise<T>(of type: T.Type = T.self, timeout: Int, file: StaticString = #file,
                        line: UInt = #line) -> TimedPromise<T> {

        // Create the promise as normal in NIO but schedule a task to fail it after the timeout.
        let promise = TimedPromise<T>(eventLoop: self, timeout: timeout, file: file, line: line)
        return promise
    }
}
