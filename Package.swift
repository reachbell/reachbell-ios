// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ReachBell",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ReachBell", targets: ["ReachBell"])
    ],
    targets: [
        .target(name: "ReachBell", path: "Sources/ReachBell"),
        .testTarget(name: "ReachBellTests", dependencies: ["ReachBell"], path: "Tests/ReachBellTests")
    ]
)
