// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "agent-client-toolkit-swift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AgoraAgentClientToolkit",
            targets: [
                "AgoraAgentClientToolkit",
                "AgoraAgentClientToolkitDependencies"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS.git", .exact("4.5.1")),
        .package(url: "https://github.com/AgoraIO/AgoraRTM_iOS.git", .exact("2.2.8"))
    ],
    targets: [
        .binaryTarget(
            name: "AgoraAgentClientToolkit",
            url: "https://download.agora.io/swiftpm/agent-client-toolkit-swift/2.11.0/AgoraAgentClientToolkit.xcframework.zip",
            checksum: "28951971ac302a6a1c6ce81ef80562a7eac2eda865cb8c8d0d95f419c1afe477"
        ),
        .target(
            name: "AgoraAgentClientToolkitDependencies",
            dependencies: [
                .product(name: "RtcBasic", package: "AgoraRtcEngine_iOS"),
                .product(name: "AgoraRTM", package: "AgoraRTM_iOS")
            ],
            path: "Sources/AgoraAgentClientToolkitDependencies"
        )
    ]
)
