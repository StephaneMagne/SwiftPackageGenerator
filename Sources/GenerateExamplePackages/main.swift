//
//  main.swift
//  GenerateExamplePackages
//
//  Created by Stephane Magne on 2026-01-24.
//

import Foundation
import PackageGeneratorCore
import PackageGeneratorExamples

// Get the current directory
let currentDirectory = FileManager.default.currentDirectoryPath
let outputPath = "\(currentDirectory)/GeneratedPackages"

print("📍 Output directory: \(outputPath)\n")

let generator = PackageGenerator(
    graph: exampleGraph,
    configuration: exampleConfiguration,
    rootPath: outputPath
)

do {
    try generator.generate()
} catch {
    print("\n❌ Generation failed: \(error)")
    exit(1)
}

// Generate dependency graphs
print("\n📊 Generating dependency graphs...")

let graphRenderer = GraphRenderer(graph: exampleGraph, configuration: exampleConfiguration)

// Target-level graph (detailed)
let detailedDOT = graphRenderer.renderDOT()
let detailedPath = "\(outputPath)/dependency-graph-detailed.dot"
try detailedDOT.write(toFile: detailedPath, atomically: true, encoding: .utf8)
print("  ✅ dependency-graph-detailed.dot")

// Module-level graph (simplified)
let moduleDOT = graphRenderer.renderModuleLevelDOT()
let modulePath = "\(outputPath)/dependency-graph-modules.dot"
try moduleDOT.write(toFile: modulePath, atomically: true, encoding: .utf8)
print("  ✅ dependency-graph-modules.dot")

print("\n💡 To render graphs, run:")
print("   dot -Tsvg \(detailedPath) -o \(outputPath)/dependency-graph-detailed.svg")
print("   dot -Tsvg \(modulePath) -o \(outputPath)/dependency-graph-modules.svg")
