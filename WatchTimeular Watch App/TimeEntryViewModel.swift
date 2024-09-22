//
//  TimeEntryViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import Foundation

class TimeEntryViewModel: ObservableObject {
    
    func createTimeEntry(activityId: String, startedAt: Date, stoppedAt: Date, note: String, token: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Set to UTC
        let startedAtString = dateFormatter.string(from: startedAt)
        let stoppedAtString = dateFormatter.string(from: stoppedAt)
        
        print(startedAtString)
        
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

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          guard let data = data else {
            print(String(describing: error))
            return
          }
          print(String(data: data, encoding: .utf8)!)
        }

        task.resume()
    }
    
}
