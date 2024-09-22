//
//  WatchTimeularApp.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-13.
//

import SwiftUI

@main
struct WatchTimeular_Watch_AppApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(authViewModel)
        }
    }
}
