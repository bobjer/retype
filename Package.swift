// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Retype",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "Retype", targets: ["Retype"]),
    ],
    targets: [
        .executableTarget(
            name: "Retype",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "RetypeTests",
            dependencies: ["Retype"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
