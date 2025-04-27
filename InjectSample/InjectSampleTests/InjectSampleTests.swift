//
//  InjectSampleTests.swift
//  InjectSampleTests
//
//  Created by Pouya Yarandi on 4/27/25.
//

import XCTest
import Inject
@testable import InjectSample

final class InjectSampleTests: XCTestCase {

    @MainActor
    func testResolveAllDependencies() {
        // Assert if all injections work as expected
        AppContainer.shared.assertAllInjections()
    }

}
