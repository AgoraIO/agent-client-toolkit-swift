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
            url: "https://download.agora.io/swiftpm/agent-client-toolkit-swift/2.10.1/AgoraAgentClientToolkit.xcframework.zip",
            checksum: "a1de265c4c573ee276091db798e2844bdc8eee25abac35af9891aac88368f5a4"
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
