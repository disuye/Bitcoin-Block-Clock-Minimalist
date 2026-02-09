// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BitcoinBlockClock",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "BitcoinBlockClock",
            path: "BitcoinBlockClock"
        )
    ]
)
