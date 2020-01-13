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
/*
/// - Note: MariaDB documentation for SECURE_CONNECTION is incorrect.
/// - See Also: [capabilities](https://mariadb.com/kb/en/connection/#capabilities)
internal struct MySQLCapabilities: OptionSet {
    var rawValue: UInt64

    static let CLIENT_MYSQL                         = MySQLCapabilities(rawValue: 1)
    static let FOUND_ROWS                           = MySQLCapabilities(rawValue: 2)
    static let CONNECT_WITH_DB                      = MySQLCapabilities(rawValue: 8)
    static let COMPRESS                             = MySQLCapabilities(rawValue: 32)
    static let LOCAL_FILES                          = MySQLCapabilities(rawValue: 128)
    static let IGNORE_SPACE                         = MySQLCapabilities(rawValue: 256)
    static let CLIENT_PROTOCOL_41                   = MySQLCapabilities(rawValue: 1 << 9)
    static let CLIENT_INTERACTIVE                   = MySQLCapabilities(rawValue: 1 << 10)
    static let SSL                                  = MySQLCapabilities(rawValue: 1 << 11)
    static let TRANSACTIONS                         = MySQLCapabilities(rawValue: 1 << 12)
    static let SECURE_CONNECTION                    = MySQLCapabilities(rawValue: 1 << 15)
    static let MULTI_STATEMENTS                     = MySQLCapabilities(rawValue: 1 << 16)
    static let MULTI_RESULTS                        = MySQLCapabilities(rawValue: 1 << 17)
    static let PS_MULTI_RESULTS                     = MySQLCapabilities(rawValue: 1 << 18)
    static let PLUGIN_AUTH                          = MySQLCapabilities(rawValue: 1 << 19)
    static let CONNECT_ATTRS                        = MySQLCapabilities(rawValue: 1 << 20)
    static let PLUGIN_AUTH_LENENC_CLIENT_DATA       = MySQLCapabilities(rawValue: 1 << 21)
    static let CLIENT_SESSION_TRACK                 = MySQLCapabilities(rawValue: 1 << 23)
    static let CLIENT_DEPRECATE_EOF                 = MySQLCapabilities(rawValue: 1 << 24)
    static let CLIENT_ZSTD_COMPRESSION_ALGORITHM    = MySQLCapabilities(rawValue: 1 << 26)
    static let CLIENT_CAPABILITY_EXTENSION          = MySQLCapabilities(rawValue: 1 << 29)
    static let MARIADB_CLIENT_PROGRESS              = MySQLCapabilities(rawValue: 1 << 32)
    static let MARIADB_CLIENT_COM_MULTI             = MySQLCapabilities(rawValue: 1 << 33)
    static let MARIADB_CLIENT_STMT_BULK_OPERATIONS  = MySQLCapabilities(rawValue: 1 << 34)
}
*/
