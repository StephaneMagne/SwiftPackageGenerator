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
    case root  // Special aggregator package for workspace visibility
}

// MARK: - Product Type

public enum ProductType {
    case executable
    case library
    case macro
    case plugin
    case none  // For aggregator packages without products
}

// MARK: - Module Location

public enum ModuleLocation {
    case path(String)
    case type(ModuleType)
}

// MARK: - Module Targets

public enum ModuleTarget: Hashable {
    case main
    case interface
    case views
    case macroImplementation
    case custom(String)
}

// MARK: - External Dependency

public struct ExternalDependency {
    public let url: String
    public let package: String
    public let requirement: String  // e.g., "from: \"509.0.0\""
    
    public init(url: String, package: String, requirement: String) {
        self.url = url
        self.package = package
        self.requirement = requirement
    }
}

// MARK: - Macro Configuration

public struct MacroConfiguration {
    public let swiftSyntaxVersion: String
    public let requiresCompilerPluginSupport: Bool
    
    public init(
        swiftSyntaxVersion: String = "509.0.0",
        requiresCompilerPluginSupport: Bool = true
    ) {
        self.swiftSyntaxVersion = swiftSyntaxVersion
        self.requiresCompilerPluginSupport = requiresCompilerPluginSupport
    }
}

// MARK: - Module

public struct Module: Hashable {
    public let name: String
    public let targets: [ModuleTarget]
    public let location: ModuleLocation
    public let productType: ProductType
    public let hasTests: Bool
    public let externalDependencies: [ExternalDependency]
    public let macroConfig: MacroConfiguration?

    public init(
        name: String,
        path: String,
        targets: [ModuleTarget]? = nil,
        productType: ProductType = .library,
        hasTests: Bool = true,
        externalDependencies: [ExternalDependency] = []
    ) {
        self.name = name
        self.targets = targets ?? [.main]
        self.location = .path(path)
        self.productType = productType
        self.hasTests = hasTests
        self.externalDependencies = externalDependencies
        self.macroConfig = nil
    }

    public init(
        name: String,
        type: ModuleType,
        targets: [ModuleTarget]? = nil,
        productType: ProductType = .library,
        hasTests: Bool = true,
        externalDependencies: [ExternalDependency] = []
    ) {
        self.name = name
        self.targets = targets ?? type.defaultTargets
        self.location = .type(type)
        self.productType = productType
        self.hasTests = hasTests
        self.macroConfig = type == .macro ? MacroConfiguration() : nil
        
        // Auto-inject swift-syntax for macros
        if type == .macro && externalDependencies.isEmpty {
            self.externalDependencies = [
                ExternalDependency(
                    url: "https://github.com/apple/swift-syntax.git",
                    package: "swift-syntax",
                    requirement: "from: \"509.0.0\""
                )
            ]
        } else {
            self.externalDependencies = externalDependencies
        }
    }
    
    public init(
        macroName: String,
        macroConfig: MacroConfiguration = MacroConfiguration(),
        hasTests: Bool = true
    ) {
        self.name = macroName
        self.targets = [.main, .macroImplementation]
        self.location = .type(.macro)
        self.productType = .macro
        self.hasTests = hasTests
        self.macroConfig = macroConfig
        
        // Auto-inject swift-syntax dependency
        self.externalDependencies = [
            ExternalDependency(
                url: "https://github.com/apple/swift-syntax.git",
                package: "swift-syntax",
                requirement: "from: \"\(macroConfig.swiftSyntaxVersion)\""
            )
        ]
    }
    
    // Convenience initializer for root aggregator package
    public static func root(
        name: String? = nil,
        targets: [ModuleTarget]? = nil,
        hasTests: Bool = false,
        externalDependencies: [ExternalDependency] = []
    ) -> Module {
        // Empty name means derive from rootPath during rendering
        Module(
            name: name ?? "",
            type: .root,
            targets: targets,
            productType: .none,
            hasTests: hasTests,
            externalDependencies: externalDependencies
        )
    }
    
    // Hashable conformance - use name as unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: Module, rhs: Module) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Module Path Resolution

extension Module {
    public func resolvedPath(using configuration: PackageConfiguration) -> String {
        switch location {
        case .path(let path):
            return path
        case .type(let type):
            let directory = configuration.moduleDirectoryConfiguration.directoryForType[type]!
            
            // For non-root types, append the module name to the directory
            if type == .root {
                return directory
            } else {
                return "\(directory)/\(name)"
            }
        }
    }
    
    /// Returns the module name, deriving from configuration if needed
    public func resolvedName(using configuration: PackageConfiguration) -> String {
        // If name is empty and this is a root module, derive from path
        if name.isEmpty, case .type(.root) = location {
            return configuration.moduleDirectoryConfiguration.rootModuleName
        }
        return name
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
        case .macroImplementation:
            return "\(name)Implementation"
        case .custom(let customName):
            return customName
        }
    }
    
    /// Returns all target names for this module
    public var targetNames: [String] {
        targets.map { targetName(for: $0) }
    }
    
    /// Returns default dependencies based on module type and targets
    public var defaultDependencies: [ModuleTarget: [ModuleDependency]] {
        guard case .type(let type) = location else { return [:] }
        guard targets == type.defaultTargets else { return [:] }

        switch type {
        case .utility, .root:
            return [:]
        case .client:
            return [
                .main: [
                    .target(.interface, module: self)
                ]
            ]
        case .coordinator,
             .screen:
            return [
                .main: [
                    .target(.views, module: self)
                ]
            ]
        case .macro:
            return [
                .main: [
                    .target(.macroImplementation, module: self)
                ]
            ]
        }
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
        case .macro:
            return [.main, .macroImplementation]
        case .utility, .root:
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
