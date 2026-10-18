// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DailyLedger",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DailyLedgerCore", targets: ["DailyLedgerCore"]),
        .executable(name: "DailyLedger", targets: ["DailyLedgerApp"])
    ],
    targets: [
        .target(name: "DailyLedgerCore"),
        .executableTarget(name: "DailyLedgerApp", dependencies: ["DailyLedgerCore"]),
        .testTarget(name: "DailyLedgerCoreTests", dependencies: ["DailyLedgerCore"])
    ]
)
