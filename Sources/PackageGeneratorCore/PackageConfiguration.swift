//
//  PackageConfiguration.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public struct ModuleDirectoryConfiguration {
    public let directoryForType: [ModuleType: String]
    public let rootPath: String
    
    public init(
        rootPath: String = "Modules",
        directoryForType: [ModuleType: String]? = nil
    ) {
        self.rootPath = rootPath
        
        // Generate default directories as subdirectories of root
        var defaults: [ModuleType: String] = [
            .client: "\(rootPath)/Clients",
            .coordinator: "\(rootPath)/Coordinators",
            .macro: "\(rootPath)/Macros",
            .screen: "\(rootPath)/Screens",
            .utility: "\(rootPath)/Utilities",
            .root: rootPath
        ]
        
        // Merge in custom overrides if provided
        if let customDirectories = directoryForType {
            defaults.merge(customDirectories) { _, custom in custom }
        }
        
        self.directoryForType = defaults
    }
    
    /// Extract the module name from the root path (last directory component)
    public var rootModuleName: String {
        let components = rootPath.split(separator: "/")
        return String(components.last ?? "Modules")
    }
}

public struct PackageConfiguration {
    public let appName: String
    public let swiftToolsVersion: String
    public let supportedPlatforms: [Platform]
    public let swiftSettings: [String]
    public let moduleDirectoryConfiguration: ModuleDirectoryConfiguration
    public let globalDependencies: [ModuleTargetType: [ModuleDependency]]

    public init(
        appName: String,
        swiftToolsVersion: String = "5.10",
        supportedPlatforms: [Platform],
        swiftSettings: [String],
        moduleDirectoryConfiguration: ModuleDirectoryConfiguration,
        globalDependencies: [ModuleTargetType: [ModuleDependency]] = [:]
    ) {
        self.appName = appName
        self.swiftToolsVersion = swiftToolsVersion
        self.supportedPlatforms = supportedPlatforms
        self.swiftSettings = swiftSettings
        self.moduleDirectoryConfiguration = moduleDirectoryConfiguration
        self.globalDependencies = globalDependencies
    }
}
