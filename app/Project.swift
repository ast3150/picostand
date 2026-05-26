import ProjectDescription

let project = Project(
    name: "StandingDesk",
    targets: [
        .target(
            name: "StandingDesk",
            destinations: .macOS,
            product: .app,
            bundleId: "com.appswithlove.standingdesk",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Standing Desk",
                "LSUIElement": false,
                "NSHumanReadableCopyright": "© 2026",
            ]),
            buildableFolders: [
                "StandingDesk/Sources",
                "StandingDesk/Resources",
            ],
            dependencies: [
                .external(name: "ORSSerial"),
            ]
        ),
    ]
)
