//
//  ViewController.swift
//  InjectSample
//
//  Created by Pouya Yarandi on 4/23/25.
//

import UIKit
import Inject

protocol MyService {
    func printHello()
}

@Bind(MyService.self)
class MyServiceImpl: MyService {
    func printHello() {
        print("Hello World!")
    }
}

class ViewController: UIViewController {

    @Inject var myService: MyService

    override func viewDidLoad() {
        super.viewDidLoad()

        myService.printHello()
    }
}
