//
//  ContentView.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-13.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var activityViewModel = ActivityViewModel()
    @Binding var selectedTab: Int
    
    var body: some View {
        TabView(selection: $selectedTab){
            NavigationView {
                VStack {
                    if authViewModel.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    }
                    else if authViewModel.tokenFetchFailed {
                        VStack {
                            Text("Failed to load activities. Please try again.")
                                .foregroundColor(.red)
                                .padding()
                            
                            Button(action: {
                                Task {
                                    await authViewModel.refreshToken()
                                }
                            }) {
                                Text("Retry")
                                    .foregroundColor(.blue)
                                    .padding()
                            }
                        }
                    }
                    else if !authViewModel.token.isEmpty {
                        List {
                            ForEach(activityViewModel.activities, id: \.id) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    HStack {
                                        Text(activity.name).padding()
                                        Spacer()
                                        if let col = Color(hex: activity.color){
                                            Rectangle()
                                                .fill(col)
                                                .frame(width: 20, height: 20)
                                                .cornerRadius(3)
                                        }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            Task{
                                let success = await activityViewModel.fetchActivities(token: authViewModel.token)
                                if !success {
                                    authViewModel.token = ""
                                }
                            }
                        }
                    }
                    else {
                        Text("Loading...")
                            .onAppear {
                                Task {
                                    authViewModel.resetState()
                                    await authViewModel.refreshToken()
                                }
                            }
                    }
                }
                .navigationTitle("Activities")
            }
            .tabItem {
                Label("Activities", systemImage: "list.bullet")
            }
            .tag(0)
            TotalTimeView()
                .tabItem {
                    Label("Total Time", systemImage: "clock")
                }
                .tag(1)
        }
    }
}

struct TotalTimeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var timeEntryViewModel = TimeEntryViewModel()
    
    var body: some View {
        if authViewModel.isLoading {
            ProgressView("Loading...")
                .padding()
        }
        else if authViewModel.tokenFetchFailed {
            VStack {
                Text("Failed to load total time.")
                    .foregroundColor(.red)
                    .padding()
                
                Button(action: {
                    Task {
                        await authViewModel.refreshToken()
                    }
                }) {
                    Text("Retry")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
        }
        else if !authViewModel.token.isEmpty {
            VStack{
                Text("Time Tracked Today:")
                Text(timeEntryViewModel.totalTimeToday)
                    .onAppear {
                        Task {
                            let success = await timeEntryViewModel.fetchTotalTime(token: authViewModel.token)
                            if !success {
                                authViewModel.token = ""
                            }
                        }
                    }
            }
        }
        else {
            Text("Loading...")
                .onAppear {
                    Task {
                        authViewModel.resetState()
                        await authViewModel.refreshToken()
                    }
                }
        }
    }
}
    
struct ActivityDetailView: View {
    let activity: Activity
    @State private var active: Bool = false
    @State private var timer: Timer?
    @State private var elapsedSeconds = 0
    @State private var startTime: Date?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var timeEntryViewModel = TimeEntryViewModel()
    

    var body: some View {
        VStack {
            let col = Color(hex: activity.color)
            Text(activity.name)
                .font(.title3)
                .padding()
            
            Divider().padding(.bottom)
            Text(formatTime(elapsedSeconds)).font(.title2)
            
            if !active{
                Button(action: startTracking) {
                    Image(systemName: "play.fill").padding().foregroundColor(col)
                }
            } else{
                    Button(action: stopTracking) {
                        Image(systemName: "stop.fill").padding().foregroundColor(col)
                    }
            }
        }
        .onAppear(){
            NotificationCenter.default.addObserver(forName: .didBecomeActive, object: nil, queue: .main) { _ in
                updateElapsedSeconds()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .didBecomeActive, object: nil)
        }
    }
    
    func startTracking(){
        active = true
        startTime = Date()
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true){ _ in
            DispatchQueue.main.async{
                updateElapsedSeconds()
            }
        }
    }
    
    func stopTracking(){
        active = false
        timer?.invalidate()
        timer = nil
    
        if let startTime = startTime {
            Task {
                authViewModel.resetState()
                await authViewModel.refreshToken()
                let isTokenValid = !authViewModel.tokenFetchFailed
                
                if isTokenValid {
                    await timeEntryViewModel.createTimeEntry(activityId: activity.id, startedAt: startTime, stoppedAt: Date(), note: "", token: authViewModel.token)
                    let updatedTotalTimeSuccess = await timeEntryViewModel.fetchTotalTime(token: authViewModel.token)
                    if !updatedTotalTimeSuccess{
                        print("Failed to update total time after logging entry.")
                    }
                } else {
                    print("Failed to refresh token. Cannot create time entry.")
                }
            }
        }
        
        elapsedSeconds = 0
    }
    
    func updateElapsedSeconds() {
        if let startTime = startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension Notification.Name {
    static let didBecomeActive = Notification.Name("didBecomeActive")
}
