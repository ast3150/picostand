// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "ORSSerial": .framework,
        ]
    )
#endif

let package = Package(
    name: "StandingDeskDeps",
    dependencies: [
        .package(url: "https://github.com/armadsen/ORSSerialPort", from: "2.1.0"),
    ]
)
