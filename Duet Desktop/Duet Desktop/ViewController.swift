//
//  ViewController.swift
//  Duet Desktop
//
//  Created by Frederick Morlock on 7/19/17.
//  Copyright © 2017 Frederick Morlock. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let warpPoint = CGPoint(x: 42, y: 42);
        CGWarpMouseCursorPosition(warpPoint);
        CGAssociateMouseAndMouseCursorPosition(1);
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

