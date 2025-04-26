// The Swift Programming Language
// https://docs.swift.org/swift-book

import Inject

@Bind
public class TextProvider {

    public init() {}

    public func hello() -> String {
        return "Hello, World!"
    }
}
