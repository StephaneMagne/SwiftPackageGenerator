//
//  SampleModuleRegistry.swift
//  SwiftPackageGenerator
//
//  Created by Stephane Magne on 2026-01-24.
//

extension Module {
    // Screens
    static var screenA: Module {
        Module(
            name: "ScreenA",
            type: .screen,
            hasTests: true
        )
    }

    static var screenB: Module {
        Module(
            name: "ScreenB",
            type: .screen,
            hasTests: true
        )
    }

    // Coordinators
    static var tabCoordinator: Module {
        Module(
            name: "TabCoordinator",
            type: .coordinator,
            hasTests: false
        )
    }

    // Utilities
    static var dependencyContainer: Module {
        Module(
            name: "DependencyContainer",
            type: .utility,
            hasTests: true
        )
    }

    // Macros
    static var dependencyRequirements: Module {
        Module(
            name: "DependencyRequirements",
            type: .macro,
            hasTests: false
        )
    }

    // Clients
    static var contentClient: Module {
        Module(
            name: "ContentClient",
            type: .client,
            hasTests: true
        )
    }
}
