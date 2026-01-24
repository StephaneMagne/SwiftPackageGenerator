//
//  GraphValidator.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

struct GraphValidator {
    let graph: [ModuleNode]
    
    func validate() throws {
        try validateAllModulesExist()
        try validateExportsAreInDependencies()
        try validateNoCycles()
    }
    
    private func validateAllModulesExist() throws {
        let allModuleNames = Set(graph.map { $0.module.name })
        
        for node in graph {
            // Check dependencies (extract modules from ModuleDependency)
            for dependency in node.dependencies {
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
            let dependencyModuleNames = Set(node.dependentModules.map { $0.name })
            
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
    
    private func validateNoCycles() throws {
        let nodesByName = Dictionary(uniqueKeysWithValues: graph.map { ($0.module.name, $0) })
        
        for node in graph {
            var visited = Set<String>()
            var stack = Set<String>()
            
            try detectCycle(
                from: node.module.name,
                visited: &visited,
                stack: &stack,
                nodesByName: nodesByName
            )
        }
    }
    
    private func detectCycle(
        from moduleName: String,
        visited: inout Set<String>,
        stack: inout Set<String>,
        nodesByName: [String: ModuleNode]
    ) throws {
        if stack.contains(moduleName) {
            throw ValidationError.cyclicDependency(module: moduleName)
        }
        
        if visited.contains(moduleName) {
            return
        }
        
        visited.insert(moduleName)
        stack.insert(moduleName)
        
        if let node = nodesByName[moduleName] {
            for dependencyModule in node.dependentModules {
                try detectCycle(
                    from: dependencyModule.name,
                    visited: &visited,
                    stack: &stack,
                    nodesByName: nodesByName
                )
            }
        }
        
        stack.remove(moduleName)
    }
}

// MARK: - Validation Error

enum ValidationError: Error, CustomStringConvertible {
    case missingDependency(module: String, dependency: String)
    case missingExport(module: String, export: String)
    case exportNotInDependencies(module: String, export: String)
    case cyclicDependency(module: String)
    
    var description: String {
        switch self {
        case .missingDependency(let module, let dependency):
            return "Module '\(module)' depends on '\(dependency)' which doesn't exist in the graph"
        case .missingExport(let module, let export):
            return "Module '\(module)' exports '\(export)' which doesn't exist in the graph"
        case .exportNotInDependencies(let module, let export):
            return "Module '\(module)' exports '\(export)' but doesn't depend on it"
        case .cyclicDependency(let module):
            return "Cyclic dependency detected involving module '\(module)'"
        }
    }
}
