//
//  ExampleConfiguration.swift
//  PackageGeneratorExamples
//
//  Created by Stephane Magne on 2026-01-24.
//

import PackageGeneratorCore

public let exampleConfiguration = PackageConfiguration(
    appName: "ExampleApp",
    supportedPlatforms: [
        .iOS(majorVersion: 17),
        .macOS(majorVersion: 15)
    ],
    swiftSettings: [
        ".unsafeFlags([\"-Wall\", \"-Wextra\"])",
        ".enableUpcomingFeature(\"StrictConcurrency\")"
    ],
    moduleDirectoryConfiguration: ModuleDirectoryConfiguration(
        directoryForType: [
            .client: "Modules/Clients",
            .coordinator: "Modules/Coordinators",
            .macro: "Modules/Macros",
            .screen: "Modules/Screens",
            .utility: "Modules/Utilities"
        ]
    ),
    globalDependencies: [
        .type(.coordinator, target: .main): [
            .module(.dependencyContainer)
        ],
        .type(.screen, target: .main): [
            .module(.dependencyContainer)
        ],
        .type(.screen, target: .views): [
            .module(.copyableMacros)
        ]
    ]
)
