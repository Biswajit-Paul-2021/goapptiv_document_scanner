// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "goapptiv_document_scanner",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "goapptiv-document-scanner", targets: ["goapptiv_document_scanner"])
    ],
    dependencies: [
        // Provided by the Flutter tool alongside the plugin when the app is built.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "goapptiv_document_scanner",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // Declares the camera's use of UserDefaults, a required-reason API.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
