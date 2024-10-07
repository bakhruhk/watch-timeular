//
//  TimeEntryViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import SwiftUI
import WatchKit
import WatchConnectivity
import Foundation
import WidgetKit

struct ActivityTime: Codable {
    var totalTime: Double
    var color: String
}

struct FailedTimeEntry: Codable {
    let activityId: String
    let startedAt: Date
    let stoppedAt: Date
    let note: String
}

class TimeEntryViewModel: NSObject, ObservableObject {
    
    @Published var totalTimeToday: String = "0m"
    @Published var activityTimes: [String: ActivityTime] = [:]
    private let cacheKey = "cachedActivityTimes"
    private let lastFetchKey = "lastFetchTimeActivityTimes"
    private let cacheExpiration: TimeInterval = 60 * 60 // 1 hour
    
    func createTimeEntry(activityId: String, startedAt: Date, stoppedAt: Date, note: String, token: String) async -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Set to UTC
        let startedAtString = dateFormatter.string(from: startedAt)
        let stoppedAtString = dateFormatter.string(from: stoppedAt)
        
        let parameters = """
        {
            "activityId": "\(activityId)",
            "startedAt": "\(startedAtString)",
            "stoppedAt": "\(stoppedAtString)",
            "note": {
                "text": "\(note)"
            }
        }
        """
        let postData = parameters.data(using: .utf8)

        var request = URLRequest(url: URL(string: "https://api.timeular.com/api/v4/time-entries")!,timeoutInterval: Double.infinity)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = postData
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            if httpResponse?.statusCode == 201 {
                print("Time entry created successfully.")
                return true
            } else {
                print("Failed to create time entry. Status code: \(httpResponse?.statusCode ?? 0)")
                return false
            }
        } catch {
            print("Error creating time entry: \(error)")
            return false
        }
    }
    
    func fetchTotalTime(token: String) async -> Bool {
        
        if let cachedActivityTimes = loadActivityTimesFromCache(),
           let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date,
           Date().timeIntervalSince(lastFetch) < cacheExpiration {

            DispatchQueue.main.async {
                self.activityTimes = cachedActivityTimes
            }
            return true
        }
        
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let todayStart = Calendar.current.startOfDay(for: now)
        let todayEnd = Calendar.current.date(byAdding: .hour, value: 23, to: todayStart)?.addingTimeInterval(59 * 60 + 59)
        let todayStartString = dateFormatter.string(from: todayStart)
        let todayEndString = dateFormatter.string(from: todayEnd ?? now)
    
        var request = URLRequest(url: URL(string: "https://api.timeular.com/api/v4/time-entries/\(todayStartString)/\(todayEndString)")!,timeoutInterval: Double.infinity)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        do{
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            
            if httpResponse?.statusCode == 401 {
                return false
            }
            else if httpResponse?.statusCode == 200 {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                if let timeEntries = jsonResponse["timeEntries"] as? [[String: Any]] {
                    var totalSeconds = 0.0
                    var activityTimes: [String: ActivityTime] = [:]
                    let entryDateFormatter = DateFormatter()
                    entryDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    entryDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    for timeEntry in timeEntries {
                        if let duration = timeEntry["duration"] as? [String: String],
                           let startedAtString = duration["startedAt"],
                           let stoppedAtString = duration["stoppedAt"],
                           let activity = timeEntry["activity"] as? [String: Any],
                           let activityName = activity["name"] as? String,
                           let activityColor = activity["color"] as? String {
                            
                            if let startedAt = entryDateFormatter.date(from: startedAtString),
                               let stoppedAt = entryDateFormatter.date(from: stoppedAtString) {
                                let timeInterval = stoppedAt.timeIntervalSince(startedAt)
                                totalSeconds += timeInterval
                                
                                if var activityTime = activityTimes[activityName] {
                                    activityTime.totalTime += timeInterval
                                    activityTimes[activityName] = activityTime
                                } else {
                                    activityTimes[activityName] = ActivityTime(totalTime: timeInterval, color: activityColor)
                                }
                            }
                        }
                    }
                    
                    let totalMinutes = totalSeconds / 60.0
                    let hours = Int(totalMinutes / 60.0)
                    let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60.0))
                    
                    DispatchQueue.main.async{
                        self.totalTimeToday = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
                        self.activityTimes = activityTimes
                        TimeTrackedManager.shared.saveTotalTrackedTime(self.totalTimeToday)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    
                    return true
                    
                } else {
                    print("No time entries found")
                }
            }
        } catch {
            print("Failed to parse JSON: \(error)")
        }
        return false
    }
    
    private func cacheActivityTimes(_ activityTimes: [String: ActivityTime]) {
        let cachedActivityTimes = activityTimes.mapValues { activityTime in
            ActivityTime(totalTime: activityTime.totalTime, color: activityTime.color)
        }
        
        if let encodedActivityTimes = try? JSONEncoder().encode(cachedActivityTimes) {
            UserDefaults.standard.set(encodedActivityTimes, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
        }
    }
    
    // Load cached activity times from UserDefaults
    private func loadActivityTimesFromCache() -> [String: ActivityTime]? {
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedActivityTimes = try? JSONDecoder().decode([String: ActivityTime].self, from: cachedData) {
            return cachedActivityTimes.mapValues { cachedActivityTime in
                ActivityTime(totalTime: cachedActivityTime.totalTime, color: cachedActivityTime.color)
            }
        }
        return nil
    }
}

func addToBacklog(_ entry: FailedTimeEntry) {
    var backlog = getBacklog()
    backlog.append(entry)
    saveBacklog(backlog)
}

func getBacklog() -> [FailedTimeEntry] {
    if let data = UserDefaults.standard.data(forKey: "backlogQueue") {
        let decoder = JSONDecoder()
        if let backlog = try? decoder.decode([FailedTimeEntry].self, from: data) {
            return backlog
        }
    }
    return []
}

func saveBacklog(_ backlog: [FailedTimeEntry]) {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(backlog) {
        UserDefaults.standard.set(data, forKey: "backlogQueue")
    }
}
