// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SlotKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlotKit", targets: ["SlotKit"]),
        .executable(name: "slotkit-demo", targets: ["slotkit-demo"]),
    ],
    targets: [
        .target(name: "SlotKit"),
        .executableTarget(
            name: "slotkit-demo",
            dependencies: ["SlotKit"],
        ),
        .testTarget(
            name: "SlotKitTests",
            dependencies: ["SlotKit"],
        ),
    ],
)
