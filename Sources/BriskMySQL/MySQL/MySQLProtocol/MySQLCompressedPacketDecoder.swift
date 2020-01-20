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

internal class MySQLCompressedPacketDecoder: ByteToMessageDecoder {
    typealias InboundOut = ByteBuffer
    var compressionEnabled = false

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if compressionEnabled {
            guard var packet = MySQLCompressedPacket(buffer: &buffer) else { return .needMoreData }
            context.fireChannelRead(wrapInboundOut(try packet.decompressBody()))
            return .continue
        } else {
            guard let packet = MySQLStandardPacket(buffer: &buffer) else { return .needMoreData }
            context.fireChannelRead(wrapInboundOut(packet.toByteBuffer()))
            return .continue
        }
    }

    func decodeLast(context: ChannelHandlerContext,
                    buffer: inout ByteBuffer,
                    seenEOF: Bool) throws -> DecodingState {

        return .needMoreData
    }
}
