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
            .dependencyRequirements
        ],
        exports: [
            .dependencyRequirements
        ]
    ),
    ModuleNode(
        module: .contentClient
    ),
    ModuleNode(
        module: .dependencyRequirements
    )
]
