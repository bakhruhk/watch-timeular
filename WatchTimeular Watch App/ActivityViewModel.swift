//
//  ActivityViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import Foundation

class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    
    private let cacheKey = "cachedActivities"
    private let lastFetchKey = "lastFetchTime"
    private let cacheExpiration: TimeInterval = 60 * 60
    
    func fetchActivities(token: String) async -> Bool {
        
        if let cachedActivities = loadActivitiesFromCache(),
           let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date,
           Date().timeIntervalSince(lastFetch) < cacheExpiration {

            DispatchQueue.main.async {
                print("here!")
                self.activities = cachedActivities
            }
            return true
        }
        
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
                    self.cacheActivities(httpResponse.activities)
                    return true
                }
            }
        } catch {
            print("Failed to fetch activities: \(error)")
        }
        return false
    }
    
    private func cacheActivities(_ activities: [Activity]) {
        if let encodedActivities = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(encodedActivities, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey) // Save the time of fetching
        }
    }
    
    private func loadActivitiesFromCache() -> [Activity]? {
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let decodedActivities = try? JSONDecoder().decode([Activity].self, from: cachedData) {
            return decodedActivities
        }
        return nil
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
