//
//  ExampleGraph.swift
//  PackageGeneratorExamples
//
//  Created by Stephane Magne on 2026-01-24.
//

import PackageGeneratorCore

public let exampleGraph: [ModuleNode] = [
    ModuleNode(
        module: .tabCoordinator,
        dependencies: [
            .target(.views, module: .screenA),
            .target(.views, module: .screenB),
            .module(.dependencyContainer)
        ]
    ),
    ModuleNode(
        module: .screenA,
        dependencies: [
            .module(.dependencyContainer),
            .target(.interface, module: .contentClient)
        ]
    ),
    ModuleNode(
        module: .screenB,
        dependencies: [
            .module(.dependencyContainer),
            .target(.interface, module: .contentClient)
        ]
    ),
    ModuleNode(
        module: .dependencyContainer,
        dependencies: [
            .module(.dependencyRequirements)
        ],
        exports: [
            .dependencyRequirements
        ]
    ),
    // Example: ContentClient with per-target dependencies
    // - ContentClient (main) depends on networking
    // - ContentClientInterface has no dependencies
    ModuleNode(
        module: .contentClient,
        dependencies: [
            .main: [
                // Main implementation needs networking, but interface doesn't
                .module(.someNetworkingModule)
            ],
            .interface: []  // Interface has no dependencies
        ]
    ),
    ModuleNode(
        module: .dependencyRequirements
    ),
    ModuleNode(
        module: .someNetworkingModule
    )
]

// Example showing the full power of per-target dependencies:
public let advancedExample = ModuleNode(
    module: .screenA,
    dependencies: [
        .main: [
            .target(.interface, module: .contentClient),  // Impl depends on its own interface
            .module(.screenB),
            .module(.dependencyContainer)
        ],
        .interface: [
            // Interface only depends on data models
            .target(.interface, module: .contentClient),  // Impl depends on its own interface
        ]
    ]
)
