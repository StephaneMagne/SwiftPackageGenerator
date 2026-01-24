//
//  PackageStructure.swift
//  SwiftPackageGenerator
//
//  Created by Stephane Magne on 2026-01-24.
//

// MARK: - Module Structure

enum ModuleType {
    case client
    case coordinator
    case macro
    case screen
    case utility
}

enum ProdcutType {
    case executable
    case library
    case macro
    case plugin
}

enum ModuleLocation {
    case path(String)
    case type(ModuleType)
}

struct Module {
    let name: String
    let location: ModuleLocation
    let productType: ProdcutType
    let hasTests: Bool

    init(
        name: String,
        path: String,
        productType: ProdcutType = .library,
        hasTests: Bool = true
    ) {
        self.name = name
        self.location = .path(path)
        self.productType = productType
        self.hasTests = hasTests
    }

    init(
        name: String,
        type: ModuleType,
        productType: ProdcutType = .library,
        hasTests: Bool = true
    ) {
        self.name = name
        self.location = .type(type)
        self.productType = productType
        self.hasTests = hasTests
    }
}

// MARK: - Module Node

struct ModuleNode {
    let module: Module
    let dependencies: [Module]
    let exports: [Module]

    init(
        module: Module,
        dependencies: [Module],
        exports: [Module] = []
    ) {
        self.module = module
        self.dependencies = dependencies
        self.exports = exports
    }
}

// MARK: - Configuration

enum Platform {
    case macOS(majorVersion: Int)
    case iOS(majorVersion: Int)
    case tvOS(majorVersion: Int)
    case watchOS(majorVersion: Int)
    case visionOS(majorVersion: Int)
    case linux
}

struct ModuleDirectoryConfiguration {
    let directoryForType: [ModuleType: String]
}

struct PackageConfiguration {
    let supportedPlatforms: [Platform]
    let swiftSettings: [String]
    let moduleDirectoryConfiguration: ModuleDirectoryConfiguration
}

let exampleConfiguration = PackageConfiguration(
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
    )
)
