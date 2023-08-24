// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Adafruit_BLE",
    products: [
        .library(
            name: "Adafruit_BLE",
            targets: ["Adafruit_BLE"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/microswift-packages/Arduino", .branch("main")),
        .package(url: "file:///Users/petoc01/Documents/Code/Arduino", .branch("main")),
    ],
    targets: [
        .target(
            name: "Adafruit_BLE",
            dependencies: ["Arduino"],
            path: "microswift",
            sources: ["main.swift"]),
    ]
)
