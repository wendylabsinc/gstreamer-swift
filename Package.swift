// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GStreamer",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
        .tvOS("26.0"),
        .watchOS("26.0"),
        .visionOS("26.0"),
    ],
    products: [
        .library(
            name: "GStreamer",
            targets: ["GStreamer"]
        ),
    ],
    targets: [
        // MARK: - System Libraries

        .systemLibrary(
            name: "CGStreamer",
            pkgConfig: "gstreamer-1.0",
            providers: [
                .brew(["gstreamer"]),
                .apt(["libgstreamer1.0-dev"]),
            ]
        ),

        .systemLibrary(
            name: "CGStreamerApp",
            pkgConfig: "gstreamer-app-1.0",
            providers: [
                .brew(["gstreamer"]),
                .apt(["libgstreamer-plugins-base1.0-dev"]),
            ]
        ),

        .systemLibrary(
            name: "CGStreamerVideo",
            pkgConfig: "gstreamer-video-1.0",
            providers: [
                .brew(["gstreamer"]),
                .apt(["libgstreamer-plugins-base1.0-dev"]),
            ]
        ),

        // MARK: - C Shim Layer

        .target(
            name: "CGStreamerShim",
            dependencies: ["CGStreamer", "CGStreamerApp", "CGStreamerVideo"],
            path: "Sources/CGStreamerShim",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),

        // MARK: - Swift API

        .target(
            name: "GStreamer",
            dependencies: ["CGStreamer", "CGStreamerApp", "CGStreamerVideo", "CGStreamerShim"],
            path: "Sources/GStreamer",
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        ),

        // MARK: - Examples

        .executableTarget(
            name: "gst-play",
            dependencies: ["GStreamer"],
            path: "Examples/gst-play"
        ),

        .executableTarget(
            name: "gst-appsink",
            dependencies: ["GStreamer"],
            path: "Examples/gst-appsink"
        ),

        .executableTarget(
            name: "gst-audio",
            dependencies: ["GStreamer"],
            path: "Examples/gst-audio"
        ),

        .executableTarget(
            name: "gst-audio-source",
            dependencies: ["GStreamer"],
            path: "Examples/gst-audio-source"
        ),

        .executableTarget(
            name: "gst-audio-sink",
            dependencies: ["GStreamer"],
            path: "Examples/gst-audio-sink"
        ),

        .executableTarget(
            name: "gst-devices",
            dependencies: ["GStreamer"],
            path: "Examples/gst-devices"
        ),

        .executableTarget(
            name: "gst-appsrc",
            dependencies: ["GStreamer"],
            path: "Examples/gst-appsrc"
        ),

        .executableTarget(
            name: "gst-tee",
            dependencies: ["GStreamer"],
            path: "Examples/gst-tee"
        ),

        .executableTarget(
            name: "gst-video-source",
            dependencies: ["GStreamer"],
            path: "Examples/gst-video-source"
        ),

        .executableTarget(
            name: "gst-vision",
            dependencies: ["GStreamer"],
            path: "Examples/gst-vision"
        ),

        .executableTarget(
            name: "gst-visualizer",
            dependencies: ["GStreamer"],
            path: "Examples/gst-visualizer"
        ),

        // MARK: - Tests

        .testTarget(
            name: "GStreamerTests",
            dependencies: ["GStreamer"],
            path: "Tests/SwiftGStreamerTests",
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
