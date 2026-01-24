//
//  PackageConfiguration.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public struct ModuleDirectoryConfiguration {
    public let directoryForType: [ModuleType: String]
    
    public init(directoryForType: [ModuleType: String]) {
        self.directoryForType = directoryForType
    }
}

public struct PackageConfiguration {
    public let supportedPlatforms: [Platform]
    public let swiftSettings: [String]
    public let moduleDirectoryConfiguration: ModuleDirectoryConfiguration
    
    public init(
        supportedPlatforms: [Platform],
        swiftSettings: [String],
        moduleDirectoryConfiguration: ModuleDirectoryConfiguration
    ) {
        self.supportedPlatforms = supportedPlatforms
        self.swiftSettings = swiftSettings
        self.moduleDirectoryConfiguration = moduleDirectoryConfiguration
    }
}
