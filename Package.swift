// swift-tools-version:5.1
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
import PackageDescription

let package = Package(
    name: "BriskMySQL",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "BriskMySQL", targets: ["BriskMySQL"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", .exact("2.12.0"))
        //.package(url: "https://github.com/apple/swift-nio-ssl.git", .exact("2.5.0")),
        //.package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .exact("1.3.0")),
        //.package(url: "https://github.com/SusanDoggie/SwiftCompression.git", .exact("1.0.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in dependencies.
        .target(name: "BriskMySQL", dependencies: ["NIO"]),
        .testTarget(name: "BriskMySQLTests", dependencies: ["BriskMySQL"])
    ]
)
