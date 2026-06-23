// swift-tools-version:5.5

import PackageDescription

// Publishing manifest for the SwiftPM package.
// Keep the package identity aligned with the repository name and keep the
// Swift module/product name stable.
let package = Package(
    name: "agent-client-toolkit-swift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AgoraAgentClientToolkit",
            targets: ["AgoraAgentClientToolkit"]
        )
    ],
    dependencies: [
        // Transitive Agora SDK dependencies required by AgoraAgentClientToolkit.
        // Consumer apps do not need to add them again unless they call RTC/RTM APIs directly.
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS.git", from: "4.5.1"),
        .package(url: "https://github.com/AgoraIO/AgoraRTM_iOS.git", from: "2.2.8")
    ],
    targets: [
        .target(
            name: "AgoraAgentClientToolkit",
            dependencies: [
                .product(name: "RtcBasic", package: "AgoraRtcEngine_iOS"),
                .product(name: "AgoraRTM", package: "AgoraRTM_iOS")
            ],
            path: "AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes"
        )
    ]
)
