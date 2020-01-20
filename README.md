# BriskMySQL
![build-macOS](https://github.com/ckmjreynolds/BriskMySQL/workflows/build-macOS/badge.svg) ![build-linux](https://github.com/ckmjreynolds/BriskMySQL/workflows/build-linux/badge.svg)  ![lint](https://github.com/ckmjreynolds/BriskMySQL/workflows/lint/badge.svg) ![license](https://img.shields.io/badge/license-MIT-brightgreen) ![semver](https://img.shields.io/badge/semver-2.0.0-brightgreen) ![Swift](https://img.shields.io/badge/Swift-5.1-brightgreen)

![os](https://img.shields.io/badge/os-macOS-brightgreen) ![os](https://img.shields.io/badge/os-linux-brightgreen) ![MySQL](https://img.shields.io/badge/MySQL-8.0.18-brightgreen) ![MariaDB](https://img.shields.io/badge/MariaDB-10.4.11-brightgreen) ![ProxySQL](https://img.shields.io/badge/ProxySQL-2.0.8-brightgreen)

## Development Status
### Protocols and Authentication
| Feature | ProxySQL | MariaDB | MySQL | Notes |
| ------- | -------- | ------- | ----- | ----- |
| Auth - `mysql_native_password` | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Auth - `caching_sha2_password` | N/A | N/A | :heavy_check_mark:* | Requires SSL/TLS. |
| SSL/TLS - Protocol Encryption | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Packet compression | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |

### Features
| Feature | ProxySQL | MariaDB | MySQL | Notes |
| ------- | -------- | ------- | ----- | ----- |
| `COM_PING` aka `isConnected()` | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| `COM_QUERY` | :x: | :x: | :x: | Target `0.1.2` |

## Sample Usage
```Swift
import Foundation
import NIO
import BriskMySQL

var eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let eventLoop = eventLoopGroup.next()

do {
    try MySQLConnection.withDatabase(to: URL(string: "mysql://root:@127.0.0.1:3306/mysql")!, on: eventLoop) { conn in
        conn.isConnected()
    }.map { result in
        print(result)
    }.wait()
}
catch {
    print(error.localizedDescription)
}
```
