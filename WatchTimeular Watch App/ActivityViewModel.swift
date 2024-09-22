//
//  ActivityViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import Foundation

class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    
    func fetchActivities(token: String) async -> Bool{
        let url = URL(string: "https://api.timeular.com/api/v3/activities")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do{
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            
            if httpResponse?.statusCode == 401 {  // Token is invalid
                return false
            } else if httpResponse?.statusCode == 200 {
                if let httpResponse = try? JSONDecoder().decode(ActivitiesResponse.self, from: data) {
                    DispatchQueue.main.async {
                        self.activities = httpResponse.activities
                    }
                }
                return true
            }
        } catch {
            print("Failed to fetch activities: \(error)")
        }
        return false
    }
}

struct Activity: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
}

struct ActivitiesResponse: Codable {
    let activities: [Activity]
}
