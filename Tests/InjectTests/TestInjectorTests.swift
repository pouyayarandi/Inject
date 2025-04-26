import XCTest
@testable import Inject

@MainActor
final class TestInjectorTests: XCTestCase {
    // Test protocols and classes
    private protocol TestService {
        func getValue() -> String
    }
    
    private class TestServiceImpl: TestService {
        func getValue() -> String {
            return "original value"
        }
    }
    
    private class MockService: TestService {
        func getValue() -> String {
            return "mock value"
        }
    }
    
    // Test class with single injectable dependency
    @MainActor
    private class SingleDependencyClass {
        @Inject var service: TestService
        
        func getServiceValue() -> String {
            return service.getValue()
        }
    }
    
    // Test class with multiple injectable dependencies of the same type
    @MainActor
    private class MultiDependencyClass {
        @Inject var service1: TestService
        @Inject var service2: TestService
        
        func getServiceValues() -> [String] {
            return [service1.getValue(), service2.getValue()]
        }
    }
    
    // Test class with keyed injectable dependencies
    @MainActor
    private class KeyedDependencyClass {
        @Inject var mainService: TestService
        @Inject var backupService: TestService
        
        func getServiceValues() -> [String] {
            return [mainService.getValue(), backupService.getValue()]
        }
    }
    
    // Test class with no injectable dependencies
    @MainActor
    private class NoDependencyClass {
        var nonInjectedProperty: String = "regular property"
    }
    
    override func setUp() async throws {
        // Reset and register dependencies before each test
        AppContainer.shared.reset()
        
        // Register test dependencies
        AppContainer.shared.register(TestService.self) {
            TestServiceImpl()
        }
    }
    
    func testInjectSingleDependency() throws {
        // Arrange
        let sut = SingleDependencyClass()
        let mockService = MockService()
        let injector = TestInjector(sut)
        
        // Verify initial state uses container-provided dependency
        XCTAssertEqual(sut.getServiceValue(), "original value")
        
        // Act
        try injector.inject(mockService, as: TestService.self)
        
        // Assert
        XCTAssertEqual(sut.getServiceValue(), "mock value")
    }
    
    func testInjectMultipleDependenciesOfSameType() throws {
        // Arrange
        let sut = MultiDependencyClass()
        let mockService = MockService()
        let injector = TestInjector(sut)
        
        // Verify initial state
        XCTAssertEqual(sut.getServiceValues(), ["original value", "original value"])
        
        // Act
        try injector.inject(mockService, as: TestService.self)
        
        // Assert - both properties should be injected
        XCTAssertEqual(sut.getServiceValues(), ["mock value", "mock value"])
    }
    
    func testInjectWithKey() throws {
        // Arrange
        let sut = KeyedDependencyClass()
        let mockService = MockService()
        let injector = TestInjector(sut)
        
        // Verify initial state
        XCTAssertEqual(sut.getServiceValues(), ["original value", "original value"])
        
        // Act - inject only mainService using key
        try injector.inject(mockService, as: TestService.self, key: "mainService")
        
        // Assert - only mainService should be mocked
        XCTAssertEqual(sut.getServiceValues(), ["mock value", "original value"])
    }
    
    func testChainedInjection() throws {
        // Arrange
        let sut = MultiDependencyClass()
        let mockService1 = MockService()
        let mockService2 = MockService()
        let injector = TestInjector(sut)
        
        // Act - test builder pattern with chained calls
        try injector
            .inject(mockService1, as: TestService.self, key: "service1")
            .inject(mockService2, as: TestService.self, key: "service2")
        
        // Assert - both should be mocked
        XCTAssertEqual(sut.getServiceValues(), ["mock value", "mock value"])
    }
    
    func testInjectableNotFound() throws {
        // Arrange
        let sut = NoDependencyClass()
        let mockService = MockService()
        let injector = TestInjector(sut)
        
        // Act & Assert - should throw when no injectable is found
        XCTAssertThrowsError(try injector.inject(mockService, as: TestService.self)) { error in
            XCTAssertTrue(String(describing: error).contains("Injectable not found for type"))
        }
    }
    
    func testInjectDifferentType() throws {
        // Arrange
        let sut = SingleDependencyClass()
        let injector = TestInjector(sut)
        
        // Different type than what's expected
        let wrongType = "string value"
        
        // Act & Assert - should fail due to type mismatch
        XCTAssertThrowsError(try injector.inject(wrongType)) { error in
            XCTAssertTrue(String(describing: error).contains("Injectable not found for type"))
        }
    }
} 