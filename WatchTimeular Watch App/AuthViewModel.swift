//
//  AuthViewModel.swift
//  WatchTimeular Watch App
//
//  Created by Harshit Bakhru on 2024-09-15.
//

import Foundation

class AuthViewModel: ObservableObject {
    @Published var token: String = ""
    @Published var isLoading: Bool = false
    @Published var tokenFetchFailed: Bool = false
    
    private var apiKey: String {
        return ProcessInfo.processInfo.environment["API_KEY"] ?? ""
    }
    
    private var apiSecret: String {
        return ProcessInfo.processInfo.environment["API_SECRET"] ?? ""
    }
    
    init() {
        if let savedToken = UserDefaults.standard.string(forKey: "token") {
            self.token = savedToken
        }
    }
    
    func fetchToken() async throws -> String {
        let parameters = """
        {
            "apiKey": "\(apiKey)",
            "apiSecret": "\(apiSecret)"
        }
        """
        
        guard let postData = parameters.data(using: .utf8) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: URL(string: "https://api.timeular.com/api/v4/developer/sign-in")!, timeoutInterval: Double.infinity)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = postData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse) // Handle failed response
        }
        
        // Parse the token from the response
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let token = json["token"] as? String {
            DispatchQueue.main.async {
                self.token = token
                UserDefaults.standard.set(token, forKey: "token")
            }
            return token
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
    
    func refreshToken() async {
        if token.isEmpty{
            do {
                _ = try await fetchToken()
            } catch {
                DispatchQueue.main.async {
                    self.tokenFetchFailed = true
                }
            }
        }
    }
    
    func resetState() {
        isLoading = false
        tokenFetchFailed = false
    }
}
