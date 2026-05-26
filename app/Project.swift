import ProjectDescription

let project = Project(
    name: "Picostand",
    targets: [
        .target(
            name: "Picostand",
            destinations: .macOS,
            product: .app,
            bundleId: "com.appswithlove.picostand",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Picostand",
                "LSUIElement": false,
                "NSHumanReadableCopyright": "© 2026",
            ]),
            buildableFolders: [
                "Picostand/Sources",
                "Picostand/Resources",
            ],
            dependencies: [
                .external(name: "ORSSerial"),
            ]
        ),
    ]
)
