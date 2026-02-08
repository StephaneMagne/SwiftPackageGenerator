//
//  ModuleNode.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public enum ModuleDependency: Hashable {
    case module(Module)
    case target(ModuleTarget, module: Module)
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .module(let module):
            hasher.combine("module")
            hasher.combine(module.name)
        case .target(let target, let module):
            hasher.combine("target")
            hasher.combine(target)
            hasher.combine(module.name)
        }
    }
    
    public static func == (lhs: ModuleDependency, rhs: ModuleDependency) -> Bool {
        switch (lhs, rhs) {
        case (.module(let m1), .module(let m2)):
            return m1.name == m2.name
        case (.target(let t1, let m1), .target(let t2, let m2)):
            return t1 == t2 && m1.name == m2.name
        default:
            return false
        }
    }
}

public struct ModuleNode {
    public let module: Module
    public let dependencies: [ModuleTarget: [ModuleDependency]]
    public let exports: [Module]

    public init(
        module: Module,
        dependencies: [Module] = [],
        exports: [Module] = []
    ) {
        self.module = module
        // Apply module dependencies to the main target only
        self.dependencies = dependencies.isEmpty ? [:] : [
            .main: dependencies.map { .module($0) }
        ]
        self.exports = exports
    }

    public init(
        module: Module,
        dependencies: [ModuleDependency],
        exports: [Module] = []
    ) {
        self.module = module
        // Apply dependencies to the main target only
        self.dependencies = dependencies.isEmpty ? [:] : [
            .main: dependencies
        ]
        self.exports = exports
    }

    public init(
        module: Module,
        dependencies: [ModuleTarget: [ModuleDependency]],
        exports: [Module] = []
    ) {
        self.module = module
        self.dependencies = dependencies
        self.exports = exports
    }
}

// MARK: - Dependency Helpers

extension ModuleNode {
    /// Returns all unique modules that this node depends on (across all targets), including global dependencies.
    func dependentModules(using configuration: PackageConfiguration) -> [Module] {
        var modules: [Module] = []
        var seen: Set<String> = []
        
        for target in module.targets {
            let deps = dependencies(for: target, using: configuration)
            for dependency in deps {
                let depModule: Module
                switch dependency {
                case .module(let m):
                    depModule = m
                case .target(_, let m):
                    depModule = m
                }
                
                if !seen.contains(depModule.name) {
                    modules.append(depModule)
                    seen.insert(depModule.name)
                }
            }
        }
        
        return modules
    }
    
    /// Returns all unique modules that this node depends on (across all targets).
    /// Note: Prefer `dependentModules(using:)` to include global dependencies from configuration.
    var dependentModules: [Module] {
        var modules: [Module] = []
        var seen: Set<String> = []
        
        for (_, deps) in dependencies {
            for dependency in deps {
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
        }
        
        return modules
    }
    
    /// Returns dependencies for a specific target, merging global, module-type defaults, and explicit dependencies.
    /// Merge order: global (from configuration) → module-type defaults → explicit node dependencies
    func dependencies(for target: ModuleTarget, using configuration: PackageConfiguration) -> [ModuleDependency] {
        // Get explicit dependencies
        let explicitDeps = dependencies[target] ?? []
        
        // Get default dependencies for this target (internal, e.g., main -> views)
        let defaultDeps = module.defaultDependencies[target] ?? []
        
        // Get global dependencies from configuration (based on module type + target)
        let globalDeps: [ModuleDependency]
        if case .type(let moduleType, _, _) = module.location {
            let key = ModuleTargetType(type: moduleType, target: target)
            globalDeps = configuration.globalDependencies[key] ?? []
        } else {
            globalDeps = []
        }
        
        // Merge and deduplicate: global → defaults → explicit
        var seen = Set<ModuleDependency>()
        var result: [ModuleDependency] = []
        
        // Add global dependencies first
        for dep in globalDeps {
            if seen.insert(dep).inserted {
                result.append(dep)
            }
        }
        
        // Add module-type defaults
        for dep in defaultDeps {
            if seen.insert(dep).inserted {
                result.append(dep)
            }
        }
        
        // Then add explicit dependencies
        for dep in explicitDeps {
            if seen.insert(dep).inserted {
                result.append(dep)
            }
        }
        
        return result
    }
    
    /// Returns dependencies for a specific target, merging with default dependencies and removing duplicates.
    /// Note: Prefer `dependencies(for:using:)` to include global dependencies from configuration.
    func dependencies(for target: ModuleTarget) -> [ModuleDependency] {
        // Get explicit dependencies
        let explicitDeps = dependencies[target] ?? []
        
        // Get default dependencies for this target
        let defaultDeps = module.defaultDependencies[target] ?? []
        
        // Merge and deduplicate using Set
        var seen = Set<ModuleDependency>()
        var result: [ModuleDependency] = []
        
        // Add defaults first
        for dep in defaultDeps {
            if seen.insert(dep).inserted {
                result.append(dep)
            }
        }
        
        // Then add explicit dependencies (may override or add to defaults)
        for dep in explicitDeps {
            if seen.insert(dep).inserted {
                result.append(dep)
            }
        }
        
        return result
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

// MARK: - First Class Module Detection

extension ModuleNode {
    /// Whether this node depends on a specific first-class module (by name),
    /// checking both explicit node dependencies and global dependencies from configuration.
    func dependsOn(firstClassModule firstClass: Module, using configuration: PackageConfiguration? = nil) -> Bool {
        // Check explicit node dependencies
        for (_, deps) in dependencies {
            for dep in deps {
                switch dep {
                case .module(let m) where m.name == firstClass.name:
                    return true
                case .target(_, let m) where m.name == firstClass.name:
                    return true
                default:
                    continue
                }
            }
        }

        // Check global dependencies from configuration (only for matching module type + targets)
        if let configuration, case .type(let moduleType, _, _) = module.location {
            for target in module.targets {
                let key = ModuleTargetType(type: moduleType, target: target)
                guard let deps = configuration.globalDependencies[key] else { continue }
                for dep in deps {
                    switch dep {
                    case .module(let m) where m.name == firstClass.name:
                        return true
                    case .target(_, let m) where m.name == firstClass.name:
                        return true
                    default:
                        continue
                    }
                }
            }
        }

        return false
    }

    /// Whether this node depends on `ModularDependencyContainer`.
    func usesModularDependencyContainer(using configuration: PackageConfiguration? = nil) -> Bool {
        dependsOn(firstClassModule: .modularDependencyContainer, using: configuration)
    }

    /// Whether this node depends on `ModularNavigation`.
    func usesModularNavigation(using configuration: PackageConfiguration? = nil) -> Bool {
        dependsOn(firstClassModule: .modularNavigation, using: configuration)
    }
}
