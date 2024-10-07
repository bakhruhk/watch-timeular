//
//  ContentView.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-13.
//

import Charts
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
                        ProgressView("Loading activities...")
                            .padding()
                    }
                    else if authViewModel.tokenFetchFailed {
                        errorView(message: "Failed to load activities. Please try again.") {
                            Task {
                                authViewModel.resetState()
                                let success = await authViewModel.refreshToken()
                                if success {
                                    await reloadActivities()
                                }
                            }
                        }
                    }
                    else if !authViewModel.token.isEmpty {
                        if activityViewModel.isLoading{
                            ProgressView("Fetching Activities...").padding()
                        } else if activityViewModel.fetchFailed {
                            errorView(message: "Failed to fetch activities. Please try again."){
                                Task {
                                    await reloadActivities()
                                }
                            }
                        }
                        else{
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
                                Task {
                                    await reloadActivities() // Fetch activities when list appears
                                }
                            }
                        }
                    }
                    else {
                        Text("Loading...")
                            .onAppear {
                                Task {
                                    authViewModel.resetState()
                                    let success = await authViewModel.refreshToken()
                                    if success {
                                        await reloadActivities()
                                    }
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
    
    func reloadActivities() async {
        let success = await activityViewModel.fetchActivities(token: authViewModel.token)
        if !success {
            authViewModel.token = "" // Invalidate token on failure
        }
    }
    
    @ViewBuilder
    func errorView(message: String, retryAction: @escaping () -> Void) -> some View {
        VStack {
            Text(message)
                .foregroundColor(.red)
                .padding()
            
            Button(action: {
                retryAction()
            }) {
                Text("Retry")
                    .foregroundColor(.blue)
                    .padding()
            }
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
            TabView{
                VStack{
                    VStack{
                        Label{
                            Text(timeEntryViewModel.totalTimeToday)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        } icon: {}
                        Label{
                            Text("Logged Today")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } icon: {}
                    } .onAppear {
                        Task {
                            await retryBacklogEntries()
                            let success = await timeEntryViewModel.fetchTotalTime(token: authViewModel.token)
                            if !success {
                                authViewModel.token = ""
                            }
                        }
                    }
                    
                    BarChartView(activityTimes: timeEntryViewModel.activityTimes)
                        .padding()
    
                }
                ActivityProgressView(activityTimes: timeEntryViewModel.activityTimes)
            }.tabViewStyle(.carousel)
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
    
    func retryBacklogEntries() async {
        var backlog = getBacklog()
        guard !backlog.isEmpty else { return }

        authViewModel.resetState()
        await authViewModel.refreshToken()
        let isTokenValid = !authViewModel.tokenFetchFailed

        if isTokenValid {
            for entry in backlog {
                let success = await timeEntryViewModel.createTimeEntry(activityId: entry.activityId, startedAt: entry.startedAt, stoppedAt: entry.stoppedAt, note: entry.note, token: authViewModel.token)
                if success {
                    backlog.removeAll { $0.startedAt == entry.startedAt && $0.stoppedAt == entry.stoppedAt }
                }
            }
            saveBacklog(backlog)
        }
    }
}

struct ActivityProgressView: View {
    let activityTimes: [String: ActivityTime]
    
    var body: some View {
        List {
            ForEach(Array(activityTimes.keys), id: \.self) { activity in
                if let activityTime = activityTimes[activity] {
                    HStack {
                        Text(activity)
                        Spacer()
                        Text(formattedTimeString(from: activityTime.totalTime))
                            .foregroundColor(Color(hex: activityTime.color))
                    }
                }
            }
        }
        .navigationTitle("Activity List")
    }

    func formattedTimeString(from seconds: Double) -> String {
        let minutes = seconds / 60.0
        let hours = Int(minutes / 60.0)
        let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60.0))

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

struct BarChartView: View {
    let activityTimes: [String: ActivityTime]

    var body: some View {
        let totalTime = activityTimes.values.reduce(0) { $0 + $1.totalTime }
        
        if totalTime > 0 {
            VStack {
                Chart {
                    ForEach(Array(activityTimes.keys), id: \.self) { activity in
                        if let activityTime = activityTimes[activity] {
                            BarMark(
                                x: .value("Minutes", activityTime.totalTime / 60)
                                //y: .value("Activity", activity)
                            )
                            .foregroundStyle(Color(hex: activityTime.color) ?? Color.gray)
                        }
                    }
                }
                .frame(height: 75)
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
            .padding()
        } else {
            Text("No Data")
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
                
                let failedEntry = FailedTimeEntry(activityId: activity.id, startedAt: startTime, stoppedAt: Date(), note: "")
                
                if isTokenValid {
                    let success = await timeEntryViewModel.createTimeEntry(activityId: activity.id, startedAt: startTime, stoppedAt: Date(), note: "", token: authViewModel.token)
                    if !success{
                        addToBacklog(failedEntry)
                    }
                    let updatedTotalTimeSuccess = await timeEntryViewModel.fetchTotalTime(token: authViewModel.token)
                    if !updatedTotalTimeSuccess{
                        print("Failed to update total time after logging entry.")
                    }
                } else {
                    addToBacklog(failedEntry)
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
