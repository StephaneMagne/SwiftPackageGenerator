//
//  GraphValidator.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

struct GraphValidator {
    let graph: [ModuleNode]
    let configuration: PackageConfiguration
    
    func validate() throws {
        try validateAllModulesExist()
        try validateExportsAreInDependencies()
        try validateTargetsExist()
        try validateNoCycles()
    }
    
    private func validateAllModulesExist() throws {
        let allModuleNames = Set(graph.map { $0.module.name })
        
        for node in graph {
            // Check all resolved dependencies (includes global dependencies)
            for target in node.module.targets {
                let deps = node.dependencies(for: target, using: configuration)
                for dependency in deps {
                    let dependencyModule: Module
                    switch dependency {
                    case .module(let module):
                        dependencyModule = module
                    case .target(_, let module):
                        dependencyModule = module
                    }
                    
                    guard allModuleNames.contains(dependencyModule.name) else {
                        throw ValidationError.missingDependency(
                            module: node.module.name,
                            dependency: dependencyModule.name
                        )
                    }
                }
            }
            
            // Check exports
            for export in node.exports {
                guard allModuleNames.contains(export.name) else {
                    throw ValidationError.missingExport(
                        module: node.module.name,
                        export: export.name
                    )
                }
            }
        }
    }
    
    private func validateExportsAreInDependencies() throws {
        for node in graph {
            let dependencyModuleNames = Set(node.dependentModules(using: configuration).map { $0.name })
            
            for export in node.exports {
                guard dependencyModuleNames.contains(export.name) else {
                    throw ValidationError.exportNotInDependencies(
                        module: node.module.name,
                        export: export.name
                    )
                }
            }
        }
    }
    
    private func validateTargetsExist() throws {
        for node in graph {
            let validTargets = Set(node.module.targets)
            
            for (target, _) in node.dependencies {
                guard validTargets.contains(target) else {
                    throw ValidationError.invalidTarget(
                        module: node.module.name,
                        target: target
                    )
                }
            }
        }
    }
    
    private func validateNoCycles() throws {
        // Build a graph of target nodes
        // Key: "ModuleName.TargetName"
        var targetGraph: [String: Set<String>] = [:]
        
        for node in graph {
            for target in node.module.targets {
                let targetKey = targetNodeKey(module: node.module.name, target: target)
                let deps = node.dependencies(for: target, using: configuration)
                
                var dependencyKeys = Set<String>()
                for dep in deps {
                    let depKey: String
                    switch dep {
                    case .module(let module):
                        // Depending on a module means depending on its main target
                        depKey = targetNodeKey(module: module.name, target: .main)
                    case .target(let depTarget, let module):
                        depKey = targetNodeKey(module: module.name, target: depTarget)
                    }
                    dependencyKeys.insert(depKey)
                }
                
                targetGraph[targetKey] = dependencyKeys
            }
        }
        
        // Now detect cycles in the target graph
        for targetKey in targetGraph.keys {
            var visited = Set<String>()
            var stack = Set<String>()
            
            try detectCycleInTargetGraph(
                from: targetKey,
                visited: &visited,
                stack: &stack,
                targetGraph: targetGraph
            )
        }
    }
    
    private func targetNodeKey(module: String, target: ModuleTarget) -> String {
        let targetName: String
        switch target {
        case .main:
            targetName = "main"
        case .interface:
            targetName = "interface"
        case .views:
            targetName = "views"
        case .custom(let name):
            targetName = name
        case .macroImplementation:
            targetName = "implementation"
        case .tests:
            targetName = "tests"
        }
        return "\(module).\(targetName)"
    }
    
    private func detectCycleInTargetGraph(
        from targetKey: String,
        visited: inout Set<String>,
        stack: inout Set<String>,
        targetGraph: [String: Set<String>]
    ) throws {
        if stack.contains(targetKey) {
            throw ValidationError.cyclicDependency(target: targetKey)
        }
        
        if visited.contains(targetKey) {
            return
        }
        
        visited.insert(targetKey)
        stack.insert(targetKey)
        
        if let dependencies = targetGraph[targetKey] {
            for dependencyKey in dependencies {
                try detectCycleInTargetGraph(
                    from: dependencyKey,
                    visited: &visited,
                    stack: &stack,
                    targetGraph: targetGraph
                )
            }
        }
        
        stack.remove(targetKey)
    }
}

// MARK: - Validation Error

enum ValidationError: Error, CustomStringConvertible {
    case missingDependency(module: String, dependency: String)
    case missingExport(module: String, export: String)
    case exportNotInDependencies(module: String, export: String)
    case cyclicDependency(target: String)
    case invalidTarget(module: String, target: ModuleTarget)
    
    var description: String {
        switch self {
        case .missingDependency(let module, let dependency):
            return "Module '\(module)' depends on '\(dependency)' which doesn't exist in the graph"
        case .missingExport(let module, let export):
            return "Module '\(module)' exports '\(export)' which doesn't exist in the graph"
        case .exportNotInDependencies(let module, let export):
            return "Module '\(module)' exports '\(export)' but doesn't depend on it"
        case .cyclicDependency(let target):
            return "Cyclic dependency detected involving target '\(target)'"
        case .invalidTarget(let module, let target):
            return "Module '\(module)' has dependencies for target '\(target)' which doesn't exist in its targets list"
        }
    }
}
