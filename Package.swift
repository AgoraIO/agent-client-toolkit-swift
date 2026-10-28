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
            url: "https://download.agora.io/swiftpm/agent-client-toolkit-swift/2.10.2/AgoraAgentClientToolkit.xcframework.zip",
            checksum: "e291a5cf75262e8b7d169ea98c2c0280b419be304940bbe3c64454e3660557d5"
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
