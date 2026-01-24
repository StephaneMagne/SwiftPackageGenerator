//
//  ExportsRenderer.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

extension ModuleNode {
    func renderExports() -> String {
        let exportStatements = exports
            .map { "@_exported import \($0.name)" }
            .joined(separator: "\n")
        
        return """
        //
        //  \(module.name)+Exports.swift
        //
        //  Created by Stephane Magne
        //
        
        \(exportStatements)
        """
    }
}
