// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftPackageGenerator",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "PackageGeneratorCore",
            targets: ["PackageGeneratorCore"]
        ),
        .library(
            name: "PackageGeneratorExamples",
            targets: ["PackageGeneratorExamples"]
        ),
        .executable(
            name: "generate-example-packages",
            targets: ["GenerateExamplePackages"]
        )
    ],
    targets: [
        .target(
            name: "PackageGeneratorCore",
            dependencies: []
        ),
        .target(
            name: "PackageGeneratorExamples",
            dependencies: ["PackageGeneratorCore"]
        ),
        .executableTarget(
            name: "GenerateExamplePackages",
            dependencies: [
                "PackageGeneratorCore",
                "PackageGeneratorExamples"
            ]
        )
    ]
)
