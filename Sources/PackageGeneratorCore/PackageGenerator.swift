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
            
            if node.module.hasTests {
                try createTestsStructure(for: node, at: fullPath)
            }
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
        // Create a directory and placeholder file for each target
        for target in node.module.targets {
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
}
