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

@Bind(MyService.self)
class MyServiceImpl: MyService {

    @Inject var textProvider: TextProvider

    func printHello() {
        print(textProvider.hello())
    }
}

class ViewController: UIViewController {

    @Inject var myService: MyService

    override func viewDidLoad() {
        super.viewDidLoad()
        myService.printHello()
    }
}
