//
//  PackageGenerator.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

import Foundation

public struct PackageGenerator {
    public let graph: [ModuleNode]
    public let configuration: PackageConfiguration
    public let rootPath: String
    
    public init(
        graph: [ModuleNode],
        configuration: PackageConfiguration,
        rootPath: String
    ) {
        self.graph = graph
        self.configuration = configuration
        self.rootPath = rootPath
    }
    
    public func generate() throws {
        print("🔍 Validating graph...")
        try validate()
        print("✅ Graph validation passed")
        
        print("\n📦 Generating packages...")
        for node in graph {
            try generatePackage(for: node)
            
            if !node.exports.isEmpty {
                try generateExports(for: node)
            }
        }
        
        print("\n🎉 All packages generated successfully!")
    }
    
    private func validate() throws {
        let validator = GraphValidator(graph: graph, configuration: configuration)
        try validator.validate()
    }
    
    private func generatePackage(for node: ModuleNode) throws {
        // Check if this is a root package
        if case .type(.root, _, _) = node.module.location {
            try generateRootPackage(for: node)
            return
        }
        
        let modulePath = node.module.resolvedPath(using: configuration)
        let fullPath = "\(rootPath)/\(modulePath)"
        
        // Check if this is a new module (root directory doesn't exist yet)
        let isNewModule = !FileManager.default.fileExists(atPath: fullPath)
        
        // Create module root directory
        try FileManager.default.createDirectory(
            atPath: fullPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Only create subdirectories and files if this is a completely new module
        if isNewModule {
            try createSourcesStructure(for: node, at: fullPath)
        }
        
        // Always regenerate Package.swift
        let packageContent = node.renderPackage(
            using: configuration,
            graph: graph
        )
        let packagePath = "\(fullPath)/Package.swift"
        try packageContent.write(
            toFile: packagePath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(modulePath)/Package.swift")
    }
    
    private func generateRootPackage(for node: ModuleNode) throws {
        let modulePath = node.module.resolvedPath(using: configuration)
        let fullPath = "\(rootPath)/\(modulePath)"
        
        // Create root directory
        try FileManager.default.createDirectory(
            atPath: fullPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create _ directory for the test target
        let testsPath = "\(fullPath)/_"
        try FileManager.default.createDirectory(
            atPath: testsPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create placeholder Swift file so SPM doesn't complain about empty target
        let placeholderContent = """
        //
        //  Tests.swift
        //  Root Test Target
        //
        //  This file exists only to satisfy Swift Package Manager's requirement
        //  that targets must contain at least one source file.
        //
        
        
        """
        let placeholderPath = "\(testsPath)/Tests.swift"
        try placeholderContent.write(toFile: placeholderPath, atomically: true, encoding: .utf8)
        
        // Generate root Package.swift
        let packageContent = node.renderRootPackage(
            using: configuration,
            graph: graph
        )
        let packagePath = "\(fullPath)/Package.swift"
        try packageContent.write(
            toFile: packagePath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(modulePath)/Package.swift (root aggregator)")
    }
    
    private func createSourcesStructure(for node: ModuleNode, at modulePath: String) throws {
        // Create a directory and placeholder file for each non-test target
        for target in node.module.targets where target != .tests {
            let targetName = node.module.targetName(for: target)
            let targetPath = "\(modulePath)/Sources/\(targetName)"
            
            try FileManager.default.createDirectory(
                atPath: targetPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Create Support/ directory for non-macro-implementation targets
            if target != .macroImplementation {
                try createPlaceholderSourceFile(
                    name: targetName,
                    at: "\(targetPath)/Support"
                )
                try createModuleLoggerFile(
                    for: node.module,
                    target: target,
                    at: targetPath
                )
            } else {
                try createPlaceholderSourceFile(
                    name: targetName,
                    at: targetPath
                )
            }
            
            // For the main target, generate first-class module scaffolding
            if target == .main {
                if node.module.usesNamespace {
                    try createNamespaceFile(
                        for: node.module,
                        at: targetPath
                    )
                }
                
                if node.usesModularDependencyContainer(using: configuration) {
                    try createDependenciesFile(
                        for: node.module,
                        at: targetPath
                    )
                }
                
                if node.usesModularNavigation(using: configuration) {
                    try createNavigationFiles(
                        for: node,
                        at: targetPath
                    )
                }
            }
        }
        
        // Create Tests structure if the module has a tests target
        if node.module.hasTests {
            try createTestsStructure(for: node, at: modulePath)
        }
    }
    
    private func createTestsStructure(for node: ModuleNode, at modulePath: String) throws {
        let testsPath = "\(modulePath)/Tests/\(node.module.name)Tests"
        
        try FileManager.default.createDirectory(
            atPath: testsPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try createPlaceholderTestFile(
            name: node.module.name,
            at: testsPath
        )
    }
    
    private func generateExports(for node: ModuleNode) throws {
        let modulePath = node.module.resolvedPath(using: configuration)
        
        // Generate exports in the main target
        let mainTargetName = node.module.targetName(for: .main)
        let sourcesPath = "\(rootPath)/\(modulePath)/Sources/\(mainTargetName)"
        
        let exportsContent = node.renderExports()
        let exportsPath = "\(sourcesPath)/\(node.module.name)+Exports.swift"
        
        try exportsContent.write(
            toFile: exportsPath,
            atomically: true,
            encoding: .utf8
        )
        
        print("  ✅ \(node.module.name)+Exports.swift")
    }
    
    private func createPlaceholderSourceFile(name: String, at path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let content = """
        //
        //  \(name).swift
        //  \(name)
        //
        //  Created by Stephane Magne
        //
        
        
        """
        
        let filePath = "\(path)/\(name).swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    private func createPlaceholderTestFile(name: String, at path: String) throws {
        let content = """
        //
        //  \(name)Tests.swift
        //  \(name)Tests
        //
        //  Created by Stephane Magne
        //
        
        import Testing
        @testable import \(name)
        
        
        """
        
        let filePath = "\(path)/\(name)Tests.swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    private func createModuleLoggerFile(for module: Module, target: ModuleTarget, at targetPath: String) throws {
        let supportPath = "\(targetPath)/Support"
        
        try FileManager.default.createDirectory(
            atPath: supportPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let targetName = module.targetName(for: target)
        let category: String
        
        // Build category based on module type
        if case .type(let type, _, _) = module.location {
            let typeName: String
            switch type {
            case .client: typeName = "Client"
            case .coordinator: typeName = "Coordinator"
            case .macro: typeName = "Macro"
            case .screen: typeName = "Screen"
            case .utility: typeName = "Utility"
            case .root: typeName = "Root"
            }
            category = "\(typeName).\(targetName)"
        } else {
            category = targetName
        }
        
        let content = """
        //
        //  ModuleLogger.swift
        //  \(targetName)
        //
        
        import OSLog
        
        private let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "\(configuration.appName)",
            category: "\(category)"
        )
        
        """
        
        let filePath = "\(supportPath)/ModuleLogger.swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    private func createNamespaceFile(for module: Module, at targetPath: String) throws {
        let supportPath = "\(targetPath)/Support"
        
        try FileManager.default.createDirectory(
            atPath: supportPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let content = """
        //
        //  \(module.name).swift
        //  \(module.name)
        //
        //  Created by Stephane Magne
        //
        
        public enum \(module.name) {}
        
        """
        
        let filePath = "\(supportPath)/\(module.name).swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
    
    // MARK: - Navigation Scaffolding

    private func createNavigationFiles(for node: ModuleNode, at targetPath: String) throws {
        let navigationPath = "\(targetPath)/Navigation"

        try FileManager.default.createDirectory(
            atPath: navigationPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try createNavigationDestinationFile(for: node.module, at: navigationPath)
        try createNavigationDestinationStateFile(for: node.module, at: navigationPath)
        try createNavigationDestinationViewFile(for: node.module, at: navigationPath)
        try createNavigationLiveFile(for: node, at: navigationPath)
        try createNavigationMockFile(for: node.module, at: navigationPath)
    }

    private func createNavigationDestinationFile(for module: Module, at navigationPath: String) throws {
        let content: String

        if module.usesNamespace {
            content = """
            //
            //  \(module.name)Destination.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            // MARK: - Destination Enum

            public extension \(module.name) {
                struct Destination: Hashable {
                    public enum Public: Hashable {
                        case main
                    }

                    enum Internal: Hashable {
                        // TODO: Add internal destinations or remove if not needed
                    }

                    enum External: Hashable {
                        // TODO: Add external destinations or remove if not needed
                    }

                    enum DestinationType: Hashable {
                        case `public`(Public)
                        case `internal`(Internal)
                        case external(External)
                    }

                    var type: DestinationType

                    init(_ destination: Public) {
                        self.type = .public(destination)
                    }

                    init(_ destination: Internal) {
                        self.type = .internal(destination)
                    }

                    init(_ destination: External) {
                        self.type = .external(destination)
                    }

                    public static func `public`(_ destination: Public) -> Self {
                        self.init(destination)
                    }

                    static func `internal`(_ destination: Internal) -> Self {
                        self.init(destination)
                    }

                    static func external(_ destination: External) -> Self {
                        self.init(destination)
                    }
                }
            }

            // MARK: - Entry Point

            public extension \(module.name) {
                typealias Entry = ModuleEntry<Destination, DestinationView>
            }

            """
        } else {
            content = """
            //
            //  \(module.name)Destination.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            // MARK: - Destination Enum

            public struct \(module.name)Destination: Hashable {
                public enum Public: Hashable {
                    case main
                }

                enum Internal: Hashable {
                    // TODO: Add internal destinations or remove if not needed
                }

                enum External: Hashable {
                    // TODO: Add external destinations or remove if not needed
                }

                enum DestinationType: Hashable {
                    case `public`(Public)
                    case `internal`(Internal)
                    case external(External)
                }

                var type: DestinationType

                init(_ destination: Public) {
                    self.type = .public(destination)
                }

                init(_ destination: Internal) {
                    self.type = .internal(destination)
                }

                init(_ destination: External) {
                    self.type = .external(destination)
                }

                public static func `public`(_ destination: Public) -> Self {
                    self.init(destination)
                }

                static func `internal`(_ destination: Internal) -> Self {
                    self.init(destination)
                }

                static func external(_ destination: External) -> Self {
                    self.init(destination)
                }
            }

            // MARK: - Entry Point

            public extension \(module.name)Destination {
                typealias Entry = ModuleEntry<\(module.name)Destination, \(module.name)DestinationView>
            }

            """
        }

        let filePath = "\(navigationPath)/\(module.name)Destination.swift"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func createNavigationDestinationStateFile(for module: Module, at navigationPath: String) throws {
        let content: String

        if module.usesNamespace {
            content = """
            //
            //  \(module.name)DestinationState.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            // MARK: - DestinationState Enum

            extension \(module.name) {
                enum DestinationState {
                    // PUBLIC
                    case main
                }
            }

            """
        } else {
            content = """
            //
            //  \(module.name)DestinationState.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            // MARK: - DestinationState Enum

            enum \(module.name)DestinationState {
                // PUBLIC
                case main
            }

            """
        }

        let filePath = "\(navigationPath)/\(module.name)DestinationState.swift"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func createNavigationDestinationViewFile(for module: Module, at navigationPath: String) throws {
        let content: String

        if module.usesNamespace {
            content = """
            //
            //  \(module.name)DestinationView.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public extension \(module.name) {
                struct DestinationView: View {
                    let state: DestinationState
                    let mode: NavigationMode
                    let client: NavigationClient<Destination>

                    init(
                        state: DestinationState,
                        mode: NavigationMode,
                        client: NavigationClient<Destination>
                    ) {
                        self.state = state
                        self.mode = mode
                        self.client = client
                    }

                    public var body: some View {
                        switch state {
                        // PUBLIC
                        case .main:
                            Text("main View")
                        }
                    }
                }
            }

            """
        } else {
            content = """
            //
            //  \(module.name)DestinationView.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public struct \(module.name)DestinationView: View {
                let state: \(module.name)DestinationState
                let mode: NavigationMode
                let client: NavigationClient<\(module.name)Destination>

                init(
                    state: \(module.name)DestinationState,
                    mode: NavigationMode,
                    client: NavigationClient<\(module.name)Destination>
                ) {
                    self.state = state
                    self.mode = mode
                    self.client = client
                }

                public var body: some View {
                    switch state {
                    // PUBLIC
                    case .main:
                        Text("main View")
                    }
                }
            }

            """
        }

        let filePath = "\(navigationPath)/\(module.name)DestinationView.swift"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func createNavigationLiveFile(for node: ModuleNode, at navigationPath: String) throws {
        let module = node.module
        let hasDependencies = node.usesModularDependencyContainer(using: configuration)
        let dependenciesLine = hasDependencies
            ? "dependencies: Dependencies"
            : "// TODO: Add dependencies parameter"
        let content: String

        if module.usesNamespace {
            content = """
            //
            //  \(module.name)Destination+Live.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public extension \(module.name) {
                @MainActor
                static func liveEntry(
                    publicDestination: Destination.Public,
                    \(dependenciesLine)
                ) -> Entry {
                    Entry(
                        entryDestination: .public(publicDestination),
                        builder: { destination, mode, navigationClient in
                            let state: DestinationState
                            switch destination.type {
                            // PUBLIC
                            case .public(let publicDestination):
                                switch publicDestination {
                                case .main:
                                    state = .main
                                }

                            // INTERNAL
                            case .internal:
                                fatalError("Add an internal switch once you add internal destinations.")

                            // EXTERNAL
                            case .external:
                                fatalError("Add an external switch once you add external destinations.")
                            }

                            // DESTINATION VIEW
                            return DestinationView(
                                state: state,
                                mode: mode,
                                client: navigationClient
                            )
                        }
                    )
                }
            }

            """
        } else {
            let nonNamespacedDependenciesLine = hasDependencies
                ? "dependencies: \(module.name)Dependencies"
                : "// TODO: Add dependencies parameter"

            content = """
            //
            //  \(module.name)Destination+Live.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public extension \(module.name)Destination {
                @MainActor
                static func liveEntry(
                    publicDestination: Public,
                    \(nonNamespacedDependenciesLine)
                ) -> Entry {
                    Entry(
                        entryDestination: .public(publicDestination),
                        builder: { destination, mode, navigationClient in
                            let state: \(module.name)DestinationState
                            switch destination.type {
                            // PUBLIC
                            case .public(let publicDestination):
                                switch publicDestination {
                                case .main:
                                    state = .main
                                }

                            // INTERNAL
                            case .internal:
                                fatalError("Add an internal switch once you add internal destinations.")

                            // EXTERNAL
                            case .external:
                                fatalError("Add an external switch once you add external destinations.")
                            }

                            // DESTINATION VIEW
                            return \(module.name)DestinationView(
                                state: state,
                                mode: mode,
                                client: navigationClient
                            )
                        }
                    )
                }
            }

            """
        }

        let filePath = "\(navigationPath)/\(module.name)Destination+Live.swift"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func createNavigationMockFile(for module: Module, at navigationPath: String) throws {
        let content: String

        if module.usesNamespace {
            content = """
            //
            //  \(module.name)Destination+Mock.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public extension \(module.name) {
                @MainActor
                static func mockEntry(
                    publicDestination: Destination.Public = .main
                ) -> Entry {
                    Entry(
                        entryDestination: .public(publicDestination),
                        builder: { destination, mode, navigationClient in
                            let state: DestinationState
                            switch destination.type {
                            // PUBLIC
                            case .public(let publicDestination):
                                switch publicDestination {
                                case .main:
                                    state = .main
                                }

                            // INTERNAL
                            case .internal:
                                fatalError("Add an internal switch once you add internal destinations.")

                            // EXTERNAL
                            case .external:
                                fatalError("Add an external switch once you add external destinations.")
                            }

                            // DESTINATION VIEW
                            return DestinationView(
                                state: state,
                                mode: mode,
                                client: navigationClient
                            )
                        }
                    )
                }
            }

            // MARK: - SwiftUI Preview

            #Preview {
                let entry = \(module.name).mockEntry()
                let rootClient = NavigationClient<RootDestination>.root()

                NavigationDestinationView(
                    previousClient: rootClient,
                    mode: .root,
                    entry: entry
                )
            }

            """
        } else {
            content = """
            //
            //  \(module.name)Destination+Mock.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //

            import ModularNavigation
            import SwiftUI

            public extension \(module.name)Destination {
                @MainActor
                static func mockEntry(
                    publicDestination: Public = .main
                ) -> Entry {
                    Entry(
                        entryDestination: .public(publicDestination),
                        builder: { destination, mode, navigationClient in
                            let state: \(module.name)DestinationState
                            switch destination.type {
                            // PUBLIC
                            case .public(let publicDestination):
                                switch publicDestination {
                                case .main:
                                    state = .main
                                }

                            // INTERNAL
                            case .internal:
                                fatalError("Add an internal switch once you add internal destinations.")

                            // EXTERNAL
                            case .external:
                                fatalError("Add an external switch once you add external destinations.")
                            }

                            // DESTINATION VIEW
                            return \(module.name)DestinationView(
                                state: state,
                                mode: mode,
                                client: navigationClient
                            )
                        }
                    )
                }
            }

            // MARK: - SwiftUI Preview

            #Preview {
                let entry = \(module.name)Destination.mockEntry()
                let rootClient = NavigationClient<RootDestination>.root()

                NavigationDestinationView(
                    previousClient: rootClient,
                    mode: .root,
                    entry: entry
                )
            }

            """
        }

        let filePath = "\(navigationPath)/\(module.name)Destination+Mock.swift"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Dependencies Scaffolding

    private func createDependenciesFile(for module: Module, at targetPath: String) throws {
        let dependenciesPath = "\(targetPath)/Dependencies"
        
        try FileManager.default.createDirectory(
            atPath: dependenciesPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let content: String
        
        if module.usesNamespace {
            content = """
            //
            //  \(module.name)Dependencies.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //
            
            import ModularDependencyContainer
            
            extension \(module.name) {
                @DependencyRequirements([
                ])
                public struct Dependencies: DependencyRequirements {
                    public func registerDependencies(in container: ModularDependencyContainer.DependencyContainer<Dependencies>) {
                        // Register any dependencies this module provides
                    }
                }
            }
            
            """
        } else {
            content = """
            //
            //  \(module.name)Dependencies.swift
            //  \(module.name)
            //
            //  Created by Stephane Magne
            //
            
            import ModularDependencyContainer
            
            @DependencyRequirements([
            ])
            public struct \(module.name)Dependencies: DependencyRequirements {
                public func registerDependencies(in container: ModularDependencyContainer.DependencyContainer<\(module.name)Dependencies>) {
                    // Register any dependencies this module provides
                }
            }
            
            """
        }
        
        let filePath = "\(dependenciesPath)/\(module.name)Dependencies.swift"
        try content.write(
            toFile: filePath,
            atomically: true,
            encoding: .utf8
        )
    }
}
