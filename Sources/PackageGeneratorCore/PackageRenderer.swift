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
        
        // Additional imports for macros
        let additionalImports = module.macroConfig?.requiresCompilerPluginSupport == true
            ? "\nimport CompilerPluginSupport"
            : ""
        
        // Render platforms (macros need macOS minimum)
        let platforms = renderPlatforms(configuration: configuration)
        
        // Render swift settings variable
        let swiftSettingsVar = renderSwiftSettingsVariable(configuration.swiftSettings)
        
        // Render package dependencies
        let packageDeps = renderPackageDependencies(
            modulePath: modulePath,
            configuration: configuration
        )
        
        // Render products (optional for .none product type)
        let productsSection = renderProductsSection()
        
        // Render targets
        let targets = renderTargets()
        
        return """
        // swift-tools-version: 5.10
        // ⚠️ Generated file — do not edit by hand
        import PackageDescription\(additionalImports)
        
        \(swiftSettingsVar)
        let package = Package(
            name: "\(module.name)",
            platforms: [\(platforms)],\(productsSection)\(packageDeps)
            targets: [
                \(targets)
            ]
        )
        """
    }
    
    private func renderPlatforms(configuration: PackageConfiguration) -> String {
        var platforms = configuration.supportedPlatforms
        
        // Macros require macOS(.v10_15) minimum
        if module.productType == .macro {
            let hasMacOS = platforms.contains { platform in
                if case .macOS = platform { return true }
                return false
            }
            
            if !hasMacOS {
                platforms.insert(.macOS(majorVersion: 10), at: 0)
            }
        }
        
        return platforms
            .map { $0.rendered }
            .joined(separator: ", ")
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
    
    private func renderProductsSection() -> String {
        // No products for .none product type
        guard let products = renderProducts() else { return "" }
        guard !products.isEmpty else { return "" }
        
        return """
        
            products: [
                \(products)
            ],
        """
    }
    
    private func renderProducts() -> String? {
        // No products for .none type
        guard module.productType != .none else { return nil }

        // For macros, only expose the client target (.main), not the implementation
        let productTargets = module.targets.filter { $0 != .macroImplementation }
        
        let productLines = productTargets.map { target -> String in
            let targetName = module.targetName(for: target)
            
            switch module.productType {
            case .library:
                return ".library(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .executable:
                return ".executable(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .macro:
                return ".library(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .plugin:
                return ".plugin(name: \"\(targetName)\", targets: [\"\(targetName)\"])"
            case .none:
                return ""  // Should never reach here
            }
        }
        
        return productLines.joined(separator: ",\n        ")
    }
    
    private func renderPackageDependencies(
        modulePath: String,
        configuration: PackageConfiguration
    ) -> String {
        // Combine local module dependencies and external dependencies
        var deps: [String] = []
        
        // External dependencies
        for externalDep in module.externalDependencies {
            deps.append("        .package(url: \"\(externalDep.url)\", \(externalDep.requirement))")
        }
        
        // Local module dependencies (exclude self-dependencies)
        let externalModules = dependentModules.filter { $0.name != module.name }
        for dependency in externalModules {
            let depPath = dependency.resolvedPath(using: configuration)
            let relativePath = PathUtilities.relativePath(from: modulePath, to: depPath)
            deps.append("        .package(path: \"\(relativePath)\")")
        }
        
        guard !deps.isEmpty else { return "" }
        
        return """
        
            dependencies: [
        \(deps.joined(separator: ",\n"))
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
        
        // Macro implementation targets need special handling
        if target == .macroImplementation {
            return renderMacroImplementationTarget(targetName: targetName)
        }
        
        // Get dependencies for this specific target (includes defaults + explicit, deduplicated)
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
    
    private func renderMacroImplementationTarget(targetName: String) -> String {
        // Macro implementation always depends on SwiftSyntax packages
        return """
        .macro(
                    name: "\(targetName)",
                    dependencies: [
                        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
                    ]
                )
        """
    }
    
    private func renderTargetDependencies(for target: ModuleTarget) -> String {
        // Get dependencies for this target (already includes defaults and deduplication)
        let targetDeps = dependencies(for: target)
        
        let deps = targetDeps
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
        let (depModuleName, targetName) = extractDependencyInfo(dependency)
        
        // Check if this is an internal dependency (same module)
        if depModuleName == module.name {
            // Internal dependency - use .target(name:) or string shorthand
            return "                \"\(targetName)\""
        } else {
            // External dependency - use .product(name:package:)
            return "                .product(name: \"\(targetName)\", package: \"\(depModuleName)\")"
        }
    }
    
    private func extractDependencyInfo(_ dependency: ModuleDependency) -> (moduleName: String, targetName: String) {
        switch dependency {
        case .module(let depModule):
            let targetName = depModule.targetName(for: .main)
            return (depModule.name, targetName)
        case .target(let target, let depModule):
            let targetName = depModule.targetName(for: target)
            return (depModule.name, targetName)
        }
    }
    
    private func renderTestTarget() -> String {
        // Test target depends on all module targets (internal dependency, use string shorthand)
        // Exclude macro implementation from tests
        let testableTargets = module.targets.filter { $0 != .macroImplementation }
        let testDeps = testableTargets
            .map { module.targetName(for: $0) }
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
