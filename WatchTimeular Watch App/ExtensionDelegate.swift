//
//  ExtensionDelegate.swift
//  WatchTimeular
//
//  Created by Harshit Bakhru on 2024-09-17.
//

import SwiftUI
import WatchKit
import WidgetKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    var timeWhenWristDown: Date?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var timeEntryViewModel = TimeEntryViewModel()
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                Task {
                    await authViewModel.refreshToken()
            
                    if !authViewModel.token.isEmpty {
                        let success = await timeEntryViewModel.fetchTotalTime(token: authViewModel.token)
                        if success {
                            print("Total time updated in the background.")
                            WidgetCenter.shared.reloadAllTimelines()
                        } else {
                            print("Failed to fetch total time, resetting token.")
                            authViewModel.token = "" // Clear token on failure
                        }
                    } else {
                        print("Token is empty, cannot fetch total time.")
                    }
                }
                scheduleBackgroundRefresh()
                refreshTask.setTaskCompletedWithSnapshot(false)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
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
    
    func scheduleBackgroundRefresh() {
        let refreshDate = Date().addingTimeInterval(60 * 15)
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: refreshDate, userInfo: nil) { (error) in
            if let error = error {
                print("Error scheduling background refresh: \(error)")
            } else {
                print("Background refresh scheduled.")
            }
        }
    }

}

