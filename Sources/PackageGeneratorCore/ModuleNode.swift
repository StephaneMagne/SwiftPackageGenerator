//
//  ModuleNode.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public enum ModuleDependency {
    case module(Module)
    case target(ModuleTarget, module: Module)
}

public struct ModuleNode {
    public let module: Module
    public let dependencies: [ModuleDependency]
    public let exports: [Module]

    public init(
        module: Module,
        dependencies: [Module] = [],
        exports: [Module] = []
    ) {
        self.module = module
        self.dependencies = dependencies.map { .module($0) }
        self.exports = exports
    }

    public init(
        module: Module,
        dependencies: [ModuleDependency],
        exports: [Module] = []
    ) {
        self.module = module
        self.dependencies = dependencies
        self.exports = exports
    }
}

// MARK: - Dependency Helpers

extension ModuleNode {
    /// Returns all unique modules that this node depends on
    var dependentModules: [Module] {
        var modules: [Module] = []
        var seen: Set<String> = []
        
        for dependency in dependencies {
            let module: Module
            switch dependency {
            case .module(let m):
                module = m
            case .target(_, let m):
                module = m
            }
            
            if !seen.contains(module.name) {
                modules.append(module)
                seen.insert(module.name)
            }
        }
        
        return modules
    }
    
    /// Returns the specific target name for a dependency
    func targetName(for dependency: ModuleDependency) -> String {
        switch dependency {
        case .module(let module):
            // When depending on a module without specifying target, use the main target
            return module.targetName(for: .main)
        case .target(let target, let module):
            return module.targetName(for: target)
        }
    }
}
