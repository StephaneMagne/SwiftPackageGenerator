//
//  Module.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

// MARK: - Module Type

public enum ModuleType {
    case client
    case coordinator
    case macro
    case screen
    case utility
}

// MARK: - Product Type

public enum ProductType {
    case executable
    case library
    case macro
    case plugin
}

// MARK: - Module Location

public enum ModuleLocation {
    case path(String)
    case type(ModuleType)
}

// MARK: - Module Targets

public enum ModuleTarget {
    case main
    case interface
    case views
    case custom(String)
}

// MARK: - Module

public struct Module {
    public let name: String
    public let targets: [ModuleTarget]
    public let location: ModuleLocation
    public let productType: ProductType
    public let hasTests: Bool

    public init(
        name: String,
        path: String,
        targets: [ModuleTarget]? = nil,
        productType: ProductType = .library,
        hasTests: Bool = true
    ) {
        self.name = name
        self.targets = targets ?? [.main]
        self.location = .path(path)
        self.productType = productType
        self.hasTests = hasTests
    }

    public init(
        name: String,
        type: ModuleType,
        targets: [ModuleTarget]? = nil,
        productType: ProductType = .library,
        hasTests: Bool = true
    ) {
        self.name = name
        self.targets = targets ?? type.defaultTargets
        self.location = .type(type)
        self.productType = productType
        self.hasTests = hasTests
    }
}

// MARK: - Module Path Resolution

extension Module {
    public func resolvedPath(using configuration: PackageConfiguration) -> String {
        switch location {
        case .path(let path):
            return path
        case .type(let type):
            guard let directory = configuration.moduleDirectoryConfiguration.directoryForType[type] else {
                fatalError("No directory configured for module type: \(type)")
            }
            return "\(directory)/\(name)"
        }
    }
    
    /// Returns the target name for a given ModuleTarget
    public func targetName(for target: ModuleTarget) -> String {
        switch target {
        case .main:
            return name
        case .interface:
            return "\(name)Interface"
        case .views:
            return "\(name)Views"
        case .custom(let customName):
            return customName
        }
    }
    
    /// Returns all target names for this module
    public var targetNames: [String] {
        targets.map { targetName(for: $0) }
    }
}

// MARK: - Type Helpers

extension ModuleType {
    var defaultTargets: [ModuleTarget] {
        switch self {
        case .client:
            return [.main, .interface]
        case .coordinator, .screen:
            return [.main, .views]
        case .utility, .macro:
            return [.main]
        }
    }
}

// MARK: - Target Helpers

extension ModuleTarget {
    /// Returns the target name for this target type within a given module
    func name(in module: Module) -> String {
        module.targetName(for: self)
    }
}
