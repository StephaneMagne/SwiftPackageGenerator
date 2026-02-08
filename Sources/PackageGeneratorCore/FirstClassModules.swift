//
//  FirstClassModules.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne
//

// MARK: - First Class Modules

public extension Module {

    static var modularDependencyContainer: Module {
        Module(
            name: "ModularDependencyContainer",
            type: .utility
        )
    }

    static var modularNavigation: Module {
        Module(
            name: "ModularNavigation",
            type: .utility
        )
    }
}
