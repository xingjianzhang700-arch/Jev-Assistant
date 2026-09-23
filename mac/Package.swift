// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "JevMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JevCore"),
        .executableTarget(name: "JevMac", dependencies: ["JevCore"]),
        // No Xcode on the build machine means no XCTest / Swift Testing:
        // checks are a plain program. Run: swift run JevChecks
        .executableTarget(name: "JevChecks", dependencies: ["JevCore"]),
    ]
)
