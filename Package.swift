// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Inject",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Inject",
            targets: ["Inject"]
        ),
        .plugin(
            name: "InjectGenerator",
            targets: ["InjectGeneratorPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Inject",
            dependencies: [
                "InjectMacros"
            ]
        ),
        
        // Macro implementation
        .macro(
            name: "InjectMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Code generation executable
        .executableTarget(
            name: "InjectPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        
        // Build plugin
        .plugin(
            name: "InjectGeneratorPlugin",
            capability: .buildTool(),
            dependencies: [
                "InjectPlugin"
            ]
        ),
        
        // Tests
        .testTarget(
            name: "InjectTests",
            dependencies: [
                "Inject",
                "InjectMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
