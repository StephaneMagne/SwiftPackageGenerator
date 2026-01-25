//
//  RootPackageRenderer.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

extension ModuleNode {
    /// Renders the root aggregator package
    func renderRootPackage(
        using configuration: PackageConfiguration,
        graph: [ModuleNode]
    ) -> String {
        let rootName = module.resolvedName(using: configuration)
        
        // Use resolved platforms (configuration + module + defaults)
        let platforms = module.resolvedPlatforms(using: configuration)
            .map { $0.rendered }
            .joined(separator: ", ")
        
        // Get the modules this root depends on (from the ModuleNode dependencies)
        let dependentModules = self.dependentModules
        
        // Look up the full ModuleNode for each dependency to get all targets
        let dependentNodes = dependentModules.compactMap { depModule -> ModuleNode? in
            graph.first { $0.module.name == depModule.name }
        }
        
        // Group modules by type for organization
        let groupedModules = Dictionary(grouping: dependentNodes) { node -> ModuleType in
            if case .type(let type, _, _) = node.module.location {
                return type
            }
            return .utility // Default fallback
        }
        
        // Render package dependencies
        let packageDeps = renderRootPackageDependencies(
            modules: dependentNodes,
            configuration: configuration
        )
        
        // Render target dependencies
        let targetDeps = renderRootTargetDependencies(
            groupedModules: groupedModules,
            configuration: configuration
        )
        
        return """
        // swift-tools-version: \(configuration.swiftToolsVersion)
        // ⚠️ Generated file — do not edit by hand
        import PackageDescription
        
        let package = Package(
            name: "\(rootName)",
            platforms: [\(platforms)],
            dependencies: [
        \(packageDeps)
            ],
            targets: [
                // ⚠️ NOT FOR PRODUCTION USE
                // This target exists only for workspace visibility and code search.
                // The main app should import modules directly, not through this target.
                //
                // When adding a new module:
                // 1. Add the package to `dependencies` above
                // 2. Add the product to this target's `dependencies` below
                .target(
                    name: "\(rootName)TestTarget",
                    dependencies: [
        \(targetDeps)
                    ],
                    path: "_"
                )
            ]
        )
        """
    }
    
    private func renderRootPackageDependencies(
        modules: [ModuleNode],
        configuration: PackageConfiguration
    ) -> String {
        // Group by type for clean organization
        let grouped = Dictionary(grouping: modules) { node -> String in
            if case .type(let type, _, _) = node.module.location {
                return typeLabel(for: type)
            }
            return "Other"
        }
        
        var lines: [String] = []
        
        // Render in consistent order
        let order = ["Utilities", "Clients", "Coordinators", "Screens", "Macros", "Other"]
        
        for category in order {
            guard let nodes = grouped[category], !nodes.isEmpty else { continue }
            
            lines.append("        // \(category)")
            for node in nodes.sorted(by: { $0.module.name < $1.module.name }) {
                let modulePath = node.module.resolvedPath(using: configuration)
                let relativePath = PathUtilities.relativePath(
                    from: configuration.moduleDirectoryConfiguration.rootPath,
                    to: modulePath
                )
                lines.append("        .package(path: \"\(relativePath)\"),")
            }
            lines.append("")  // Empty line between sections
        }
        
        // Remove trailing empty line and comma from last entry
        if !lines.isEmpty {
            lines.removeLast()  // Remove last empty line
            if var lastLine = lines.last, lastLine.hasSuffix(",") {
                lastLine.removeLast()
                lines[lines.count - 1] = lastLine
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func renderRootTargetDependencies(
        groupedModules: [ModuleType: [ModuleNode]],
        configuration: PackageConfiguration
    ) -> String {
        var lines: [String] = []
        
        // Render in consistent order
        let order: [ModuleType] = [.utility, .client, .coordinator, .screen, .macro]
        
        for type in order {
            guard let nodes = groupedModules[type], !nodes.isEmpty else { continue }
            
            lines.append("                // \(typeLabel(for: type))")
            for node in nodes.sorted(by: { $0.module.name < $1.module.name }) {
                // For each module, include only the main product (not interface/views)
                // This keeps the root aggregator simpler
                let mainTargetName = node.module.targetName(for: .main)
                lines.append("                .product(name: \"\(mainTargetName)\", package: \"\(node.module.name)\"),")
            }
            lines.append("")  // Empty line between sections
        }
        
        // Remove trailing empty line and comma from last entry
        if !lines.isEmpty {
            lines.removeLast()  // Remove last empty line
            if var lastLine = lines.last, lastLine.hasSuffix(",") {
                lastLine.removeLast()
                lines[lines.count - 1] = lastLine
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func typeLabel(for type: ModuleType) -> String {
        switch type {
        case .client:
            return "Clients"
        case .coordinator:
            return "Coordinators"
        case .macro:
            return "Macros"
        case .screen:
            return "Screens"
        case .utility:
            return "Utilities"
        case .root:
            return "Root"
        }
    }
}
