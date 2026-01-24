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
    
    public static var dependencyRequirements: Module {
        Module(
            name: "DependencyRequirements",
            type: .macro,
            productType: .macro,
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
}
