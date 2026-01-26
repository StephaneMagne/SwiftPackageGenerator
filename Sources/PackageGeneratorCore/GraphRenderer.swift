//
//  GraphRenderer.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-25.
//

/// Renders a module dependency graph in DOT format for Graphviz visualization.
///
/// Usage:
/// ```swift
/// let renderer = GraphRenderer(graph: myGraph, configuration: myConfig)
/// let dotContent = renderer.renderDOT()
/// try dotContent.write(toFile: "graph.dot", atomically: true, encoding: .utf8)
/// ```
///
/// Then generate SVG/PNG:
/// ```bash
/// dot -Tsvg graph.dot -o graph.svg
/// ```
public struct GraphRenderer {
    public let graph: [ModuleNode]
    public let configuration: PackageConfiguration
    
    public init(graph: [ModuleNode], configuration: PackageConfiguration) {
        self.graph = graph
        self.configuration = configuration
    }
    
    /// Renders the full dependency graph in DOT format with target-level detail.
    /// Modules are clustered by ModuleType.
    public func renderDOT() -> String {
        var lines: [String] = []
        
        lines.append("digraph ModuleDependencies {")
        lines.append("    rankdir=TB;")
        lines.append("    ranksep=1.0;")
        lines.append("    nodesep=0.8;")
        lines.append("    pad=0.5;")
        lines.append("    node [shape=box, style=filled, fontname=\"Helvetica\"];")
        lines.append("    edge [fontname=\"Helvetica\", fontsize=10];")
        lines.append("")
        
        // Group nodes by ModuleType for clustering
        let groupedNodes = Dictionary(grouping: graph) { node -> ModuleType in
            if case .type(let type, _, _) = node.module.location {
                return type
            }
            return .utility
        }
        
        // Render clusters
        let typeOrder: [ModuleType] = [.utility, .client, .screen, .coordinator, .macro, .root]
        for type in typeOrder {
            guard let nodes = groupedNodes[type], !nodes.isEmpty else { continue }
            lines.append(contentsOf: renderCluster(for: type, nodes: nodes))
            lines.append("")
        }
        
        // Render all edges
        lines.append("    // Dependencies")
        for node in graph {
            lines.append(contentsOf: renderEdges(for: node))
        }
        
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
    
    /// Renders a simplified module-level graph (no target detail).
    public func renderModuleLevelDOT() -> String {
        var lines: [String] = []
        
        lines.append("digraph ModuleDependencies {")
        lines.append("    rankdir=TB;")
        lines.append("    ranksep=1.0;")
        lines.append("    nodesep=0.8;")
        lines.append("    pad=0.5;")
        lines.append("    node [shape=box, style=filled, fontname=\"Helvetica\"];")
        lines.append("")
        
        // Group nodes by ModuleType for clustering
        let groupedNodes = Dictionary(grouping: graph) { node -> ModuleType in
            if case .type(let type, _, _) = node.module.location {
                return type
            }
            return .utility
        }
        
        // Render clusters with single node per module
        let typeOrder: [ModuleType] = [.utility, .client, .screen, .coordinator, .macro, .root]
        for type in typeOrder {
            guard let nodes = groupedNodes[type], !nodes.isEmpty else { continue }
            lines.append(contentsOf: renderModuleLevelCluster(for: type, nodes: nodes))
            lines.append("")
        }
        
        // Render module-level edges
        lines.append("    // Dependencies")
        for node in graph {
            lines.append(contentsOf: renderModuleLevelEdges(for: node))
        }
        
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Target-Level Rendering
    
    private func renderCluster(for type: ModuleType, nodes: [ModuleNode]) -> [String] {
        var lines: [String] = []
        let clusterName = clusterName(for: type)
        let color = clusterColor(for: type)
        
        lines.append("    subgraph cluster_\(clusterName) {")
        lines.append("        label=\"\(typeLabel(for: type))\";")
        lines.append("        style=filled;")
        lines.append("        color=\"\(color)\";")
        lines.append("")
        
        for node in nodes.sorted(by: { $0.module.name < $1.module.name }) {
            lines.append(contentsOf: renderModuleTargets(for: node).map { "        \($0)" })
        }
        
        lines.append("    }")
        
        return lines
    }
    
    private func renderModuleTargets(for node: ModuleNode) -> [String] {
        var lines: [String] = []
        let nodeColor = targetColor(for: node.module)
        
        // Create a subgraph for this module's targets
        lines.append("subgraph cluster_\(sanitize(node.module.name)) {")
        lines.append("    label=\"\(node.module.name)\";")
        lines.append("    style=rounded;")
        lines.append("    color=\"#666666\";")
        lines.append("")
        
        for target in node.module.targets {
            let targetName = node.module.targetName(for: target)
            let nodeId = nodeId(module: node.module.name, target: target)
            let label = targetLabel(for: target)
            lines.append("    \(nodeId) [label=\"\(label)\", fillcolor=\"\(nodeColor)\"];")
        }
        
        lines.append("}")
        
        return lines
    }
    
    private func renderEdges(for node: ModuleNode) -> [String] {
        var lines: [String] = []
        
        for target in node.module.targets {
            let sourceId = nodeId(module: node.module.name, target: target)
            let dependencies = node.dependencies(for: target)
            
            for dependency in dependencies {
                let targetId: String
                let edgeStyle: String
                
                switch dependency {
                case .module(let depModule):
                    targetId = nodeId(module: depModule.name, target: .main)
                    edgeStyle = isInternalDependency(dependency, in: node) ? "dashed" : "solid"
                case .target(let depTarget, let depModule):
                    targetId = nodeId(module: depModule.name, target: depTarget)
                    edgeStyle = isInternalDependency(dependency, in: node) ? "dashed" : "solid"
                }
                
                lines.append("    \(sourceId) -> \(targetId) [style=\(edgeStyle)];")
            }
        }
        
        return lines
    }
    
    // MARK: - Module-Level Rendering
    
    private func renderModuleLevelCluster(for type: ModuleType, nodes: [ModuleNode]) -> [String] {
        var lines: [String] = []
        let clusterName = clusterName(for: type)
        let color = clusterColor(for: type)
        
        lines.append("    subgraph cluster_\(clusterName) {")
        lines.append("        label=\"\(typeLabel(for: type))\";")
        lines.append("        style=filled;")
        lines.append("        color=\"\(color)\";")
        lines.append("")
        
        for node in nodes.sorted(by: { $0.module.name < $1.module.name }) {
            let nodeId = sanitize(node.module.name)
            let nodeColor = targetColor(for: node.module)
            lines.append("        \(nodeId) [label=\"\(node.module.name)\", fillcolor=\"\(nodeColor)\"];")
        }
        
        lines.append("    }")
        
        return lines
    }
    
    private func renderModuleLevelEdges(for node: ModuleNode) -> [String] {
        var lines: [String] = []
        let sourceId = sanitize(node.module.name)
        
        // Collect unique module dependencies (not internal)
        var seenModules = Set<String>()
        
        for target in node.module.targets {
            let dependencies = node.dependencies(for: target)
            
            for dependency in dependencies {
                // Skip internal dependencies
                guard !isInternalDependency(dependency, in: node) else { continue }
                
                let depModuleName: String
                switch dependency {
                case .module(let depModule):
                    depModuleName = depModule.name
                case .target(_, let depModule):
                    depModuleName = depModule.name
                }
                
                if !seenModules.contains(depModuleName) {
                    seenModules.insert(depModuleName)
                    let targetId = sanitize(depModuleName)
                    lines.append("    \(sourceId) -> \(targetId);")
                }
            }
        }
        
        return lines
    }
    
    // MARK: - Helpers
    
    private func isInternalDependency(_ dependency: ModuleDependency, in node: ModuleNode) -> Bool {
        switch dependency {
        case .module(let depModule):
            return depModule.name == node.module.name
        case .target(_, let depModule):
            return depModule.name == node.module.name
        }
    }
    
    private func nodeId(module: String, target: ModuleTarget) -> String {
        let targetSuffix: String
        switch target {
        case .main:
            targetSuffix = "main"
        case .interface:
            targetSuffix = "interface"
        case .views:
            targetSuffix = "views"
        case .macroImplementation:
            targetSuffix = "impl"
        case .custom(let name):
            targetSuffix = sanitize(name)
        }
        return "\(sanitize(module))_\(targetSuffix)"
    }
    
    private func targetLabel(for target: ModuleTarget) -> String {
        switch target {
        case .main:
            return "main"
        case .interface:
            return "Interface"
        case .views:
            return "Views"
        case .macroImplementation:
            return "Implementation"
        case .custom(let name):
            return name
        }
    }
    
    private func sanitize(_ name: String) -> String {
        // DOT identifiers can't have special characters
        name.replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }
    
    private func clusterName(for type: ModuleType) -> String {
        switch type {
        case .client: return "clients"
        case .coordinator: return "coordinators"
        case .macro: return "macros"
        case .screen: return "screens"
        case .utility: return "utilities"
        case .root: return "root"
        }
    }
    
    private func typeLabel(for type: ModuleType) -> String {
        switch type {
        case .client: return "Clients"
        case .coordinator: return "Coordinators"
        case .macro: return "Macros"
        case .screen: return "Screens"
        case .utility: return "Utilities"
        case .root: return "Root"
        }
    }
    
    private func clusterColor(for type: ModuleType) -> String {
        switch type {
        case .client: return "#e8f4f8"
        case .coordinator: return "#f8e8f4"
        case .macro: return "#f4f8e8"
        case .screen: return "#f8f4e8"
        case .utility: return "#e8e8f8"
        case .root: return "#f0f0f0"
        }
    }
    
    private func targetColor(for module: Module) -> String {
        // Slightly darker than cluster color for contrast
        if case .type(let type, _, _) = module.location {
            switch type {
            case .client: return "#cce7f0"
            case .coordinator: return "#f0cce7"
            case .macro: return "#e7f0cc"
            case .screen: return "#f0e7cc"
            case .utility: return "#ccccf0"
            case .root: return "#e0e0e0"
            }
        }
        return "#dddddd"
    }
}
