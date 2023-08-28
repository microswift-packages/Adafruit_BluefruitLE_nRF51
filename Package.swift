// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Adafruit_BluefruitLE_nRF51",
    products: [
        .library(
            name: "Adafruit_BluefruitLE_nRF51",
            targets: ["Adafruit_BluefruitLE_nRF51"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microswift-packages/Arduino", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Adafruit_BluefruitLE_nRF51",
            dependencies: ["Arduino"],
            path: "microswift",
            sources: ["main.swift"]),
    ]
)
