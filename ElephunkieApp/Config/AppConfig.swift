import Foundation

struct AppConfig {
    // Cloudflare Configuration
    static let cloudflareAPIToken = "XspvHdYi9Y3YSI96_5sF3pYYb4O0nW1-69Z9K2vB"
    static let cloudflareZoneID = "f3830ecd755d9a9fce0706a76853bef3"
    static let cloudflareAccountID = "a6be49a23f5c554fe6d72fa8de2506b1"
    
    // Server Configuration
    static let serverPort = 8321
    static let serverHost = "0.0.0.0"
    
    // Domain Configuration
    static let baseDomain = "connect.elephunkie.com"
    
    // Security
    static let tokenLength = 32
    static let sessionTimeout: TimeInterval = 3600 // 1 hour
    
    // Storage
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static var clientsStorageURL: URL {
        documentsDirectory.appendingPathComponent("clients.json")
    }
    
    static var logsDirectory: URL {
        documentsDirectory.appendingPathComponent("logs")
    }
    
    // Initialize storage directories
    static func initializeStorage() {
        do {
            try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create logs directory: \(error)")
        }
    }
}