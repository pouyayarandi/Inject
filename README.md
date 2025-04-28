# Inject

A Swift package that implements the service locator pattern using property wrappers and code generation. It provides a simple way to manage dependencies in your Swift applications.

## Features

- `@Bind` annotation to register implementations in the container
- `@Inject` property wrapper to resolve dependencies
- Automatic code generation during build phase
- Compile-time validation of dependencies
- Support for protocol-based dependency injection
- Singleton instance management
- Works with both SwiftPM and Xcode projects
- Supports iOS 14.0+ and macOS 11.0+

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/pouyayarandi/Inject.git", from: "1.0.0")
]
```

## Usage

### 1. Register Dependencies

Use the `@Bind` annotation to register your implementations:

```swift
protocol MyService {
    func doSomething()
}

@Bind(MyService.self)
class MyServiceImpl: MyService {
    func doSomething() {
        print("Doing something")
    }
}

// For concrete types, you can omit the type parameter
@Bind
class AnotherService {
    func anotherOperation() {
        print("Another operation")
    }
}
```

### 2. Inject Dependencies

Use the `@Inject` property wrapper to resolve dependencies:

```swift
class MyViewController {
    @Inject private var myService: MyService
    @Inject private var anotherService: AnotherService
    
    func someMethod() {
        myService.doSomething()
        anotherService.anotherOperation()
    }
}
```

The package performs compile-time validation to ensure that every type used with `@Inject` has a corresponding `@Bind` implementation. If a dependency is missing, you'll get a build error like this:

```
Missing @Bind implementations for the following dependencies:
- MyService (used at file.swift:10:5)
```

### 3. Enable Code Generation

#### For SwiftPM Projects

In your `Package.swift`, add the plugin to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Inject", package: "Inject")
    ],
    plugins: [
        .plugin(name: "InjectGenerator", package: "Inject")
    ]
)
```

#### For Xcode Projects

1. Add the Inject package to your project in Xcode
2. Select your target in Xcode
3. Go to the "Build Settings" tab
4. Enable "Build Tool Plugins" 
5. In the "Target Dependencies" section, click + and add the "InjectGenerator" plugin

There's no need to add a custom build script. The plugin will automatically:
- Run during the build phase
- Generate the container code in the build directory (not in your source files)
- Regenerate the code when dependencies change
- Keep the generated code out of source control

### 4. Initialize Container

Make sure to call `registerDependencies()` when your app starts:

```swift
@main
struct MyApp: App {
    init() {
        AppContainer.shared.registerDependencies()
    }
}
```

## Testing with TestInjector

The package includes a `TestInjector` property wrapper to help you mock dependencies in your unit tests:

```swift
class UserServiceTests: XCTestCase {
    func testUserProfile() throws {
        // Traditional approach
        let mockNetworkClient = MockNetworkClient()
        let viewModel = UserProfileViewModel()
        
        // Create injector and inject mock
        let injector = TestInjector(viewModel)
        try injector.inject(mockNetworkClient, as: NetworkClient.self)
        
        // Act and assert
        viewModel.loadProfile()
        XCTAssertEqual(viewModel.userName, "John Doe")
    }
    
    func testUserProfileWithPropertyWrapper() throws {
        // Property wrapper approach - define sut with @TestInjector
        @TestInjector var viewModel = UserProfileViewModel()
        let mockNetworkClient = MockNetworkClient()
        
        // Inject mock using the $ projected value
        try $viewModel.inject(mockNetworkClient, as: NetworkClient.self)
        
        // Act and assert
        viewModel.loadProfile()
        XCTAssertEqual(viewModel.userName, "John Doe")
    }
}
```

### Key Features

- Type-safe dependency injection for tests
- Can be used either as a property wrapper or through direct instantiation
- Allows injecting mocks into objects using `@Inject` properties
- Works with both protocol and concrete types
- Can target specific properties using the `key` parameter
- Throws descriptive errors when injection targets aren't found

This makes it easy to isolate components during unit testing without modifying your production code.

## Requirements

- Swift 5.9 or later
- iOS 14.0 or later
- macOS 11.0 or later

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
