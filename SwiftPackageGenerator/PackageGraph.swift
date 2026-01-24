//
//  SamplePackageGraph.swift
//  SwiftPackageGenerator
//
//  Created by Stephane Magne on 2026-01-24.
//

let graph: [ModuleNode] = [
    ModuleNode(
        module: .tabCoordinator,
        dependencies: [
            .screenA,
            .screenB,
            .dependencyContainer
        ]
    ),
    ModuleNode(
        module: .screenA,
        dependencies: [
            .dependencyContainer,
            .contentClient
        ]
    ),
    ModuleNode(
        module: .screenB,
        dependencies: [
            .dependencyContainer,
            .contentClient
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
        module: .contentClient,
        dependencies: []
    )
]
