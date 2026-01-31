//
//  PackageGenerator.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

import Foundation

public struct PackageGenerator {
    public let graph: [ModuleNode]
    public let configuration: PackageConfiguration
    public let rootPath: String
    
    public init(
        graph: [ModuleNode],
        configuration: PackageConfiguration,
        rootPath: String
    ) {
        self.graph = graph
        self.configuration = configuration
        self.rootPath = rootPath
    }
    
    public func generate() throws {
        print("🔍 Validating graph...")
        try validate()
        print("✅ Graph validation passed")
        
        print("\n📦 Generating packages...")
        for node in graph {
            try generatePackage(for: node)
            
            if !node.exports.isEmpty {
                try generateExports(for: node)
            }
        }
        
        print("\n🎉 All packages generated successfully!")
    }
    
    private func validate() throws {
        let validator = GraphValidator(graph: graph, configuration: configuration)
        try validator.validate()
    }
    
    private func generatePackage(for node: ModuleNode) throws {
        // Check if this is a root package
        if case .type(.root, _, _) = node.module.location {
            try generateRootPackage(for: node)
            return
        }
        
        let modulePath = node.module.resolvedPath(using: configuration)
        let fullPath = "\(rootPath)/\(modulePath)"
        
        // Check if this is a new module (root directory doesn't exist yet)
        let isNewModule = !FileManager.default.fileExists(atPath: fullPath)
        
        // Create module root directory
        try FileManager.default.createDirectory(
            atPath: fullPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Only create subdirectories and files if this is a completely new module
        if isNewModule {
            try createSourcesStructure(for: node, at: fullPath)
        }
        
        // Always regenerate Package.swift
        let packageContent = node.renderPackage(
            using: configuration,
            graph: graph
        )
        let packagePath = "\(fullPath)/Package.swift"
        try packageContent.write(
            toFile: packagePath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(modulePath)/Package.swift")
    }
    
    private func generateRootPackage(for node: ModuleNode) throws {
        let modulePath = node.module.resolvedPath(using: configuration)
        let fullPath = "\(rootPath)/\(modulePath)"
        
        // Create root directory
        try FileManager.default.createDirectory(
            atPath: fullPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create _ directory for the test target
        let testsPath = "\(fullPath)/_"
        try FileManager.default.createDirectory(
            atPath: testsPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create placeholder Swift file so SPM doesn't complain about empty target
        let placeholderContent = """
        //
        //  Tests.swift
        //  Root Test Target
        //
        //  This file exists only to satisfy Swift Package Manager's requirement
        //  that targets must contain at least one source file.
        //
        
        
        """
        let placeholderPath = "\(testsPath)/Tests.swift"
        try placeholderContent.write(toFile: placeholderPath, atomically: true, encoding: .utf8)
        
        // Generate root Package.swift
        let packageContent = node.renderRootPackage(
            using: configuration,
            graph: graph
        )
        let packagePath = "\(fullPath)/Package.swift"
        try packageContent.write(
            toFile: packagePath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(modulePath)/Package.swift (root aggregator)")
    }
    
    private func createSourcesStructure(for node: ModuleNode, at modulePath: String) throws {
        // Create a directory and placeholder file for each non-test target
        for target in node.module.targets where target != .tests {
            let targetName = node.module.targetName(for: target)
            let targetPath = "\(modulePath)/Sources/\(targetName)"
            
            try FileManager.default.createDirectory(
                atPath: targetPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try createPlaceholderSourceFile(
                name: targetName,
                at: targetPath
            )
            
            // Create Support/ModuleLogger.swift for non-macro-implementation targets
            if target != .macroImplementation {
                try createModuleLoggerFile(
                    for: node.module,
                    target: target,
                    at: targetPath
                )
            }
        }
        
        // Create Tests structure if the module has a tests target
        if node.module.hasTests {
            try createTestsStructure(for: node, at: modulePath)
        }
    }
    
    private func createTestsStructure(for node: ModuleNode, at modulePath: String) throws {
        let testsPath = "\(modulePath)/Tests/\(node.module.name)Tests"
        
        try FileManager.default.createDirectory(
            atPath: testsPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try createPlaceholderTestFile(
            name: node.module.name,
            at: testsPath
        )
    }
    
    private func generateExports(for node: ModuleNode) throws {
        let modulePath = node.module.resolvedPath(using: configuration)
        
        // Generate exports in the main target
        let mainTargetName = node.module.targetName(for: .main)
        let sourcesPath = "\(rootPath)/\(modulePath)/Sources/\(mainTargetName)"
        
        let exportsContent = node.renderExports()
        let exportsPath = "\(sourcesPath)/\(node.module.name)+Exports.swift"
        
        try exportsContent.write(
            toFile: exportsPath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(node.module.name)+Exports.swift")
    }
    
    private func createPlaceholderSourceFile(name: String, at path: String) throws {
        let content = """
        //
        //  \(name).swift
        //  \(name)
        //
        //  Created by Stephane Magne
        //
        
        
        """
        
        let filePath = "\(path)/\(name).swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    private func createPlaceholderTestFile(name: String, at path: String) throws {
        let content = """
        //
        //  \(name)Tests.swift
        //  \(name)Tests
        //
        //  Created by Stephane Magne
        //
        
        import Testing
        @testable import \(name)
        
        
        """
        
        let filePath = "\(path)/\(name)Tests.swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    private func createModuleLoggerFile(for module: Module, target: ModuleTarget, at targetPath: String) throws {
        let supportPath = "\(targetPath)/Support"
        
        try FileManager.default.createDirectory(
            atPath: supportPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let targetName = module.targetName(for: target)
        let category: String
        
        // Build category based on module type
        if case .type(let type, _, _) = module.location {
            let typeName: String
            switch type {
            case .client: typeName = "Client"
            case .coordinator: typeName = "Coordinator"
            case .macro: typeName = "Macro"
            case .screen: typeName = "Screen"
            case .utility: typeName = "Utility"
            case .root: typeName = "Root"
            }
            category = "\(typeName).\(targetName)"
        } else {
            category = targetName
        }
        
        let content = """
        //
        //  ModuleLogger.swift
        //  \(targetName)
        //
        
        import OSLog
        
        private let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "\(configuration.appName)",
            category: "\(category)"
        )
        
        """
        
        let filePath = "\(supportPath)/ModuleLogger.swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
}
