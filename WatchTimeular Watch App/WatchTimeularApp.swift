//
//  WatchTimeularApp.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-13.
//

import SwiftUI

@main
struct WatchTimeular_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var timeEntryViewModel = TimeEntryViewModel()
    @State private var selectedTab: Int = 0
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .onOpenURL{url in
                    handleDeepLink(url: url)}
                .environmentObject(authViewModel)
        }
    }
    
    private func handleDeepLink(url: URL) {
        if url.absoluteString == "watchtimeular://totaltimeview" {
            selectedTab = 1
        }
    }
}
