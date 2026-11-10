// swift-tools-version: 6.0
// ScanLabCore holds the logic that does not need the phone's sensors, so it can be
// built and tested on the build machine (ADR-003). It must only import Foundation.

import PackageDescription

let package = Package(
    name: "ScanLabCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ScanLabCore", targets: ["ScanLabCore"])
    ],
    targets: [
        .target(name: "ScanLabCore"),
        .testTarget(name: "ScanLabCoreTests", dependencies: ["ScanLabCore"]),
    ]
)
