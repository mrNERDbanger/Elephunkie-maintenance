import Foundation

struct Client: Identifiable, Codable {
    let id: UUID
    var name: String
    var siteURL: String
    var authToken: String
    var status: ClientStatus
    var lastSeen: Date?
    var wordPressVersion: String?
    var phpVersion: String?
    var plugins: [Plugin]
    var themes: [Theme]
    var healthMetrics: HealthMetrics?
    var dnsRecord: String? // e.g., "clientname.connect.elephunkie.com"
    
    init(name: String, siteURL: String) {
        self.id = UUID()
        self.name = name
        self.siteURL = siteURL
        self.authToken = UUID().uuidString
        self.status = .pending
        self.plugins = []
        self.themes = []
    }
}

enum ClientStatus: String, Codable, CaseIterable {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
    case offline = "Offline"
    case pending = "Pending"
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        case .offline: return "gray"
        case .pending: return "blue"
        }
    }
}

struct Plugin: Identifiable, Codable {
    let id = UUID()
    var name: String
    var slug: String
    var version: String
    var updateAvailable: String?
    var isActive: Bool
}

struct Theme: Identifiable, Codable {
    let id = UUID()
    var name: String
    var slug: String
    var version: String
    var updateAvailable: String?
    var isActive: Bool
}

struct HealthMetrics: Codable {
    var cpuUsage: Double
    var memoryUsage: Double
    var diskUsage: Double
    var uptime: TimeInterval
    var lastBackup: Date?
    var securityIssues: Int
    var errorCount: Int
    var timestamp: Date
}