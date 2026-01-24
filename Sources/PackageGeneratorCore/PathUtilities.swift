//
//  PathUtilities.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

import Foundation

enum PathUtilities {
    /// Calculate relative path from one module to another
    /// Example: from "Modules/Screens/ScreenA" to "Modules/Clients/ContentClient"
    /// Returns: "../../../Modules/Clients/ContentClient"
    static func relativePath(from sourcePath: String, to targetPath: String) -> String {
        let sourceComponents = sourcePath.split(separator: "/").map(String.init)
        let targetComponents = targetPath.split(separator: "/").map(String.init)
        
        // Find common prefix
        var commonPrefixLength = 0
        for (source, target) in zip(sourceComponents, targetComponents) {
            if source == target {
                commonPrefixLength += 1
            } else {
                break
            }
        }
        
        // Calculate how many levels up we need to go
        let upLevels = sourceComponents.count - commonPrefixLength
        
        // Build the relative path
        let upPath = Array(repeating: "..", count: upLevels)
        let remainingTarget = targetComponents.dropFirst(commonPrefixLength)
        
        let components = upPath + Array(remainingTarget)
        return components.joined(separator: "/")
    }
    
    /// Calculate depth of a path (number of directory levels)
    /// Example: "Modules/Screens/ScreenA" -> 3
    static func depth(of path: String) -> Int {
        path.split(separator: "/").count
    }
}
