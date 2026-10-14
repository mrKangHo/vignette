import ProjectDescription

let project = Project(
    name: "Vignette",
    organizationName: "mrkangho",
    targets: [
        .target(
            name: "Vignette",
            destinations: .macOS,
            product: .app,
            bundleId: "com.mrkangho.Vignette",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .file(path: "Resources/Vignette/Info.plist"),
            sources: ["Sources/Vignette/**"],
            resources: [
                "Resources/Vignette/Assets.xcassets",
                "Resources/Vignette/Localizable.xcstrings",
            ],
            entitlements: .file(path: "Resources/Vignette/Vignette.entitlements"),
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "CURRENT_PROJECT_VERSION": "1",
                    "MARKETING_VERSION": "0.1.1",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                ]
            )
        )
    ]
)
