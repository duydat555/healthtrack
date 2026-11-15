// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "activity_sensors",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "activity-sensors", targets: ["activity_sensors"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "activity_sensors",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
