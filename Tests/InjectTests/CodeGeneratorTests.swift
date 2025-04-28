import XCTest
@testable import InjectCore

final class CodeGeneratorTests: XCTestCase {
    
    // Test parsing source files for bindings
    func testParseSourceFiles() throws {
        // Create a temporary directory for test source files
        let tmpDirectory = NSTemporaryDirectory().appending("InjectTests")
        try? FileManager.default.removeItem(atPath: tmpDirectory)
        try FileManager.default.createDirectory(atPath: tmpDirectory, withIntermediateDirectories: true)
        
        // Create test source file with @Bind and @Inject
        let sourceCode = """
        import Foundation
        import Inject
        
        protocol TestService {
            func getValue() -> String
        }
        
        @Bind(TestService.self)
        class TestServiceImpl: TestService {
            func getValue() -> String {
                return "test"
            }
        }
        
        class Consumer {
            @Inject var service: TestService
        }
        """
        
        let filePath = (tmpDirectory as NSString).appendingPathComponent("TestFile.swift")
        try sourceCode.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        // Parse the source files
        let (bindings, injections) = try parseSourceFiles(in: [tmpDirectory])
        
        // Verify bindings are found
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings.first?.type, "TestService")
        XCTAssertEqual(bindings.first?.implementation, "TestServiceImpl")
        XCTAssertFalse(bindings.first?.isSingleton ?? true)
        
        // Verify injections are found
        XCTAssertEqual(injections.count, 1)
        XCTAssertEqual(injections.first?.type, "TestService")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: tmpDirectory)
    }
    
    // Test parsing a source file with @Singleton
    func testParseSourceFilesWithSingleton() throws {
        // Create a temporary directory for test source files
        let tmpDirectory = NSTemporaryDirectory().appending("InjectTests")
        try? FileManager.default.removeItem(atPath: tmpDirectory)
        try FileManager.default.createDirectory(atPath: tmpDirectory, withIntermediateDirectories: true)
        
        // Create test source file with @Bind, @Singleton and @Inject
        let sourceCode = """
        import Foundation
        import Inject
        
        protocol TestService {
            func getValue() -> String
        }
        
        @Singleton
        @Bind(TestService.self)
        class TestServiceImpl: TestService {
            func getValue() -> String {
                return "test"
            }
        }
        
        class Consumer {
            @Inject var service: TestService
        }
        """
        
        let filePath = (tmpDirectory as NSString).appendingPathComponent("TestFile.swift")
        try sourceCode.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        // Parse the source files
        let (bindings, _) = try parseSourceFiles(in: [tmpDirectory])
        
        // Verify bindings are found
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings.first?.type, "TestService")
        XCTAssertEqual(bindings.first?.implementation, "TestServiceImpl")
        XCTAssertTrue(bindings.first?.isSingleton ?? false)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: tmpDirectory)
    }
    
    // Test parsing a source file with multiple bindings
    func testParseSourceFilesWithMultipleBindings() throws {
        // Create a temporary directory for test source files
        let tmpDirectory = NSTemporaryDirectory().appending("InjectTests")
        try? FileManager.default.removeItem(atPath: tmpDirectory)
        try FileManager.default.createDirectory(atPath: tmpDirectory, withIntermediateDirectories: true)
        
        // Create test source file with multiple @Bind annotations
        let sourceCode = """
        import Foundation
        import Inject
        
        protocol ServiceA {
            func getValueA() -> String
        }
        
        protocol ServiceB {
            func getValueB() -> String
        }
        
        @Bind(ServiceA.self, ServiceB.self)
        class CombinedServiceImpl: ServiceA, ServiceB {
            func getValueA() -> String {
                return "A"
            }
            
            func getValueB() -> String {
                return "B"
            }
        }
        
        class Consumer {
            @Inject var serviceA: ServiceA
            @Inject var serviceB: ServiceB
        }
        """
        
        let filePath = (tmpDirectory as NSString).appendingPathComponent("TestFile.swift")
        try sourceCode.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        // Parse the source files
        let (bindings, injections) = try parseSourceFiles(in: [tmpDirectory])
        
        // Verify bindings are found
        XCTAssertEqual(bindings.count, 2)
        XCTAssertTrue(bindings.contains { $0.type == "ServiceA" && $0.implementation == "CombinedServiceImpl" })
        XCTAssertTrue(bindings.contains { $0.type == "ServiceB" && $0.implementation == "CombinedServiceImpl" })
        
        // Verify injections are found
        XCTAssertEqual(injections.count, 2)
        XCTAssertTrue(injections.contains { $0.type == "ServiceA" })
        XCTAssertTrue(injections.contains { $0.type == "ServiceB" })
        
        // Clean up
        try? FileManager.default.removeItem(atPath: tmpDirectory)
    }
    
    // Test validation of dependencies
    func testValidateDependencies() throws {
        // Valid case: all injections have corresponding bindings
        let bindings = [
            Binding(type: "ServiceA", implementation: "ServiceAImpl", location: SourceLocation(line: 1, column: 1, offset: 0, file: ""), isSingleton: false),
            Binding(type: "ServiceB", implementation: "ServiceBImpl", location: SourceLocation(line: 2, column: 1, offset: 0, file: ""), isSingleton: true)
        ]
        
        let injections = [
            InjectedDependency(type: "ServiceA", location: SourceLocation(line: 3, column: 1, offset: 0, file: "")),
            InjectedDependency(type: "ServiceB", location: SourceLocation(line: 4, column: 1, offset: 0, file: ""))
        ]
        
        // Should not throw
        XCTAssertNoThrow(try validateDependencies(bindings: bindings, injections: injections))
        
        // Invalid case: missing binding for an injection
        let invalidInjections = [
            InjectedDependency(type: "ServiceA", location: SourceLocation(line: 3, column: 1, offset: 0, file: "")),
            InjectedDependency(type: "ServiceB", location: SourceLocation(line: 4, column: 1, offset: 0, file: "")),
            InjectedDependency(type: "ServiceC", location: SourceLocation(line: 5, column: 1, offset: 0, file: ""))
        ]
        
        // Should throw ValidationError
        XCTAssertThrowsError(try validateDependencies(bindings: bindings, injections: invalidInjections)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            
            XCTAssertTrue(validationError.message.contains("ServiceC"))
        }

        // Invalid case: duplicate binding for a type
        let duplicateBindings = [
            Binding(type: "ServiceA", implementation: "ServiceA1", location: SourceLocation(line: 1, column: 1, offset: 0, file: ""), isSingleton: true),
            Binding(type: "ServiceA", implementation: "ServiceA2", location: SourceLocation(line: 2, column: 1, offset: 0, file: ""), isSingleton: true),
            Binding(type: "ServiceB", implementation: "ServiceB", location: SourceLocation(line: 3, column: 1, offset: 0, file: ""), isSingleton: true)
        ]

        // Should throw ValidationError
        XCTAssertThrowsError(try validateDependencies(bindings: duplicateBindings, injections: injections)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }

            XCTAssertTrue(validationError.message.contains("ServiceA"))
        }
    }
    
    // Test generating container code
    func testGenerateContainerCode() {
        // Setup bindings
        let bindings = [
            Binding(type: "ServiceA", implementation: "ServiceAImpl", location: SourceLocation(line: 1, column: 1, offset: 0, file: ""), isSingleton: false),
            Binding(type: "ServiceB", implementation: "ServiceBImpl", location: SourceLocation(line: 2, column: 1, offset: 0, file: ""), isSingleton: true),
            Binding(type: "ServiceC", implementation: "ServiceCImpl", location: SourceLocation(line: 3, column: 1, offset: 0, file: ""), isSingleton: true),
            Binding(type: "ServiceInterface1", implementation: "MultiService", location: SourceLocation(line: 4, column: 1, offset: 0, file: ""), isSingleton: true),
            Binding(type: "ServiceInterface2", implementation: "MultiService", location: SourceLocation(line: 5, column: 1, offset: 0, file: ""), isSingleton: true)
        ]
        
        // Generate code with custom imports
        let generatedCode = generateContainerCode(bindings: bindings, imports: ["UIKit", "Foundation"], injections: [])
        
        // Verify the generated code
        XCTAssertTrue(generatedCode.contains("import UIKit"))
        XCTAssertTrue(generatedCode.contains("import Foundation"))
        XCTAssertTrue(generatedCode.contains("import Inject"))
        
        // Check non-singleton registration
        XCTAssertTrue(generatedCode.contains("register(ServiceA.self) { ServiceAImpl() }"))
        
        // Check singleton registration
        XCTAssertTrue(generatedCode.contains("registerSingleton(ServiceB.self) { ServiceBImpl() }"))
        
        // Check multi-binding singleton optimization
        XCTAssertTrue(generatedCode.contains("let sharedMultiService = MultiService()"))
        XCTAssertTrue(generatedCode.contains("registerSingleton(ServiceInterface1.self) { sharedMultiService }"))
        XCTAssertTrue(generatedCode.contains("registerSingleton(ServiceInterface2.self) { sharedMultiService }"))
    }
} 
