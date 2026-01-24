//
//  PackageRenderer.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

extension ModuleNode {
    func renderPackage(
        using configuration: PackageConfiguration,
        graph: [ModuleNode]
    ) -> String {
        let modulePath = module.resolvedPath(using: configuration)
        
        // Render platforms
        let platforms = configuration.supportedPlatforms
            .map { $0.rendered }
            .joined(separator: ", ")
        
        // Render swift settings variable
        let swiftSettingsVar = renderSwiftSettingsVariable(configuration.swiftSettings)
        
        // Render package dependencies
        let packageDeps = renderPackageDependencies(
            modulePath: modulePath,
            configuration: configuration
        )
        
        // Render products (one per target)
        let products = renderProducts()
        
        // Render targets
        let targets = renderTargets()
        
        return """
        // swift-tools-version: 5.10
        // ⚠️ Generated file — do not edit by hand
        import PackageDescription
        
        \(swiftSettingsVar)
        let package = Package(
            name: "\(module.name)",
            platforms: [\(platforms)],
            products: [
                \(products)
            ],\(packageDeps)
            targets: [
                \(targets)
            ]
        )
        """
    }
    
    private func renderSwiftSettingsVariable(_ settings: [String]) -> String {
        let settingsBody = settings
            .map { "    \($0)" }
            .joined(separator: ",\n")
        
        return """
        let swiftSettings: [PackageDescription.SwiftSetting] = [
        \(settingsBody)
        ]
        """
    }
    
    private func renderProducts() -> String {
        let productLines = module.targets.map { target -> String in
            let targetName = module.targetName(for: target)
            
            switch module.productType {
            case .library:
                return ".library(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .executable:
                return ".executable(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .macro:
                return ".macro(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .plugin:
                return ".plugin(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            }
        }
        
        return productLines.joined(separator: ",\n        ")
    }
    
    private func renderPackageDependencies(
        modulePath: String,
        configuration: PackageConfiguration
    ) -> String {
        let uniqueModules = dependentModules
        guard !uniqueModules.isEmpty else { return "" }
        
        let deps = uniqueModules.map { dependency -> String in
            let depPath = dependency.resolvedPath(using: configuration)
            let relativePath = PathUtilities.relativePath(from: modulePath, to: depPath)
            return "        .package(path: \"\(relativePath)\")"
        }.joined(separator: ",\n")
        
        return """
        
            dependencies: [
        \(deps)
            ],
        """
    }
    
    private func renderTargets() -> String {
        let targetLines = module.targets.enumerated().map { index, target -> String in
            renderTarget(target, isLast: index == module.targets.count - 1)
        }
        
        let testTarget = module.hasTests ? ",\n        \(renderTestTarget())" : ""
        
        return targetLines.joined(separator: ",\n        ") + testTarget
    }
    
    private func renderTarget(_ target: ModuleTarget, isLast: Bool) -> String {
        let targetName = module.targetName(for: target)
        
        // Get dependencies for this specific target
        let targetDeps = renderTargetDependencies(for: target)
        
        let depsSection = targetDeps.isEmpty ? "" : """
        
                    \(targetDeps),
        """
        
        return """
        .target(
                    name: "\(targetName)",\(depsSection)
                    swiftSettings: swiftSettings
                )
        """
    }
    
    private func renderTargetDependencies(for target: ModuleTarget) -> String {
        // For now, apply all dependencies to all targets
        // You could make this more sophisticated later if needed
        let deps = dependencies
            .map { dependency -> String in
                renderDependency(dependency)
            }
            .joined(separator: ",\n")
        
        guard !deps.isEmpty else { return "" }
        
        return """
        dependencies: [
        \(deps)
                    ]
        """
    }
    
    private func renderDependency(_ dependency: ModuleDependency) -> String {
        switch dependency {
        case .module(let depModule):
            let targetName = depModule.targetName(for: .main)
            return "                .product(name: \"\(targetName)\", package: \"\(depModule.name)\")"
        case .target(let target, let depModule):
            let targetName = depModule.targetName(for: target)
            return "                .product(name: \"\(targetName)\", package: \"\(depModule.name)\")"
        }
    }
    
    private func renderTestTarget() -> String {
        // Test target depends on all module targets (internal dependency, use string shorthand)
        let testDeps = module.targetNames
            .map { "                \"\($0)\"" }
            .joined(separator: ",\n")
        
        return """
        .testTarget(
                    name: "\(module.name)Tests",
                    dependencies: [
        \(testDeps)
                    ]
                )
        """
    }
}
