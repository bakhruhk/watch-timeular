//
//  TimeTrackedManager.swift
//  WatchTimeular
//
//  Created by Harshit Bakhru on 2024-09-24.
//

import Foundation

class TimeTrackedManager{
    static let shared = TimeTrackedManager()
    private let userDefaults: UserDefaults?
    
    private init(){
        userDefaults = UserDefaults(suiteName: "group.com.watchtimeular.activity")
    }
    
    func saveTotalTrackedTime(_ time: String){
        userDefaults?.set(time, forKey: "totalTrackedTime")
    }
    
    func getTotalTrackedTime() -> String{
        return userDefaults?.string(forKey: "totalTrackedTime") ?? "0m"
    }
}
