//
//  ControlPanelViewController.swift
//  Piano-Hero
//
//  Created by Da Shen on 4/27/16.
//  Copyright © 2016 UIUC. All rights reserved.
//

import Foundation
import UIKit

class ControlPanelViewController: UIViewController {
    var controlCenter:ControlCenter = ControlCenter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("ControlPanelViewController didReceiveMemoryWarning")
    }
    
    @IBAction func connect(sender:UIButton) {
        controlCenter.connectToPianoHero()
    }
    @IBAction func loadMIDI(sender:UIButton) {
        let file = NSURL(fileReferenceLiteral: "Undertale_-_080_Finale.mid")
        controlCenter.loadMIDI(file, speed: 120, keyboardOffset: 36)
    }
    
    @IBAction func playOrPause(sender:UIButton){
        controlCenter.startPlaybackOrPause()
    }
}