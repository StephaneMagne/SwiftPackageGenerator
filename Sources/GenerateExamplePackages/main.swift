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
