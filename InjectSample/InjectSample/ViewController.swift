//
//  ViewController.swift
//  InjectSample
//
//  Created by Pouya Yarandi on 4/23/25.
//

import UIKit
import Inject
import MyLibrary

protocol MyService {
    func printHello()
}

protocol AnotherService {
    func sayGoodbye()
}

@Singleton
@Bind(
    MyService.self,
    AnotherService.self
)
class ServicesImpl: MyService, AnotherService {

    @Inject var textProvider: TextProvider

    func printHello() {
        print(textProvider.hello())
    }

    func sayGoodbye() {
        print("Goodbye!")
    }
}

class ViewController: UIViewController {

    @Inject var myService: MyService
    @Inject var anotherService: AnotherService

    override func viewDidLoad() {
        super.viewDidLoad()
        myService.printHello()
        anotherService.sayGoodbye()
    }
}
