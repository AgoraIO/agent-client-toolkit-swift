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
            url: "https://download.agora.io/swiftpm/agent-client-toolkit-swift/2.10.0/AgoraAgentClientToolkit.xcframework.zip",
            checksum: "291588f80c2eaabf14f1264ada9044cd84039566955844cd1885fb50c31ab641"
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
