//
//  ExampleModuleRegistry.swift
//  PackageGeneratorExamples
//
//  Created by Stephane Magne on 2026-01-24.
//

import PackageGeneratorCore

extension Module {
    // MARK: - Screens

    public static var screenA: Module {
        Module(
            name: "ScreenA",
            type: .screen,
            hasTests: true
        )
    }

    public static var screenB: Module {
        Module(
            name: "ScreenB",
            type: .screen,
            hasTests: true
        )
    }

    // MARK: - Coordinators

    public static var tabCoordinator: Module {
        Module(
            name: "TabCoordinator",
            type: .coordinator,
            hasTests: false
        )
    }

    // MARK: - Utilities

    public static var dependencyContainer: Module {
        Module(
            name: "DependencyContainer",
            type: .utility,
            hasTests: true
        )
    }

    // MARK: - Macros

    // Convenience: Using type-based initialization with default config
    public static var dependencyRequirements: Module {
        Module(
            name: "DependencyRequirementsMacros",
            type: .macro,
            hasTests: false
        )
    }

    // Explicit: Using dedicated macro initializer with custom config
    public static var copyableMacros: Module {
        Module(
            macroName: "CopyableMacros",
            macroConfig: MacroConfiguration(
                swiftSyntaxVersion: "509.0.0",
                requiresCompilerPluginSupport: true
            ),
            hasTests: false
        )
    }

    // MARK: - Clients

    public static var contentClient: Module {
        Module(
            name: "ContentClient",
            type: .client,
            hasTests: true
        )
    }

    public static var someNetworkingModule: Module {
        Module(
            name: "SomeNetworkingModule",
            type: .client,
            hasTests: true
        )
    }

}
