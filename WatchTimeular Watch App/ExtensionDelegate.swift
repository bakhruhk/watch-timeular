//
//  ExtensionDelegate.swift
//  WatchTimeular
//
//  Created by Harshit Bakhru on 2024-09-17.
//

import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    var timeWhenWristDown: Date?
    
    func applicationDidFinishLaunching() {

    }
    
    func applicationWillResignActive() {
        timeWhenWristDown = Date()
    }
    
    func applicationDidBecomeActive() {
        guard let timeWhenWristDown = timeWhenWristDown else { return }
        let elapsed = Date().timeIntervalSince(timeWhenWristDown)
        NotificationCenter.default.post(name: .didBecomeActive, object: nil, userInfo: ["elapsed": elapsed])
    }
    
    
}

