// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "route_tracker",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "route-tracker", targets: ["route_tracker"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "route_tracker",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
