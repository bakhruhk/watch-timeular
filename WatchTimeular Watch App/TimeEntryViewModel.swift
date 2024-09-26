//
//  TimeEntryViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import WatchKit
import WatchConnectivity
import Foundation
import WidgetKit

class TimeEntryViewModel: NSObject, ObservableObject {
    
    @Published var totalTimeToday: String = "0m"
    
    func createTimeEntry(activityId: String, startedAt: Date, stoppedAt: Date, note: String, token: String) async {
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
            } else {
                print("Failed to create time entry. Status code: \(httpResponse?.statusCode ?? 0)")
            }
        } catch {
            print("Error creating time entry: \(error)")
        }
    }
    
    func fetchTotalTime(token: String) async -> Bool {
        
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
                    let entryDateFormatter = DateFormatter()
                    entryDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    entryDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    for timeEntry in timeEntries {
                        if let duration = timeEntry["duration"] as? [String: String],
                           let startedAtString = duration["startedAt"],
                           let stoppedAtString = duration["stoppedAt"] {
                            
                            if let startedAt = entryDateFormatter.date(from: startedAtString),
                               let stoppedAt = entryDateFormatter.date(from: stoppedAtString) {
                                let timeInterval = stoppedAt.timeIntervalSince(startedAt)
                                totalSeconds += timeInterval
                            }
                        }
                    }
                    
                    let totalMinutes = totalSeconds / 60.0
                    let hours = Int(totalMinutes / 60.0)
                    let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60.0))
                    
                    DispatchQueue.main.async{
                        if (hours < 1){
                            self.totalTimeToday = "\(minutes)m"
                        }
                        else{
                            self.totalTimeToday = "\(hours)h \(minutes)m"
                        }
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
    
}
