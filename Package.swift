// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Retype",
    platforms: [
        .macOS(.v13),
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
    ]
)
