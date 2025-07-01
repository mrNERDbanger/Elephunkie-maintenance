import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class AppState: ObservableObject {
    @Published var selectedView: AppView = .dashboard
    @Published var clients: [Client] = []
    @Published var pendingUpdates: Int = 0
    @Published var openTickets: Int = 0
    @Published var unreadErrors: Int = 0
    @Published var showAddClient = false
    @Published var showReportGenerator = false
    @Published var showAbout = false
    
    private let storageManager = StorageManager()
    private let cloudflareService: CloudflareService
    
    init() {
        // Initialize with credentials from config
        self.cloudflareService = CloudflareService(
            apiToken: AppConfig.cloudflareAPIToken,
            zoneID: AppConfig.cloudflareZoneID
        )
        
        // Initialize storage
        AppConfig.initializeStorage()
        
        Task {
            await loadClients()
        }
    }
    
    func loadClients() async {
        do {
            clients = try await storageManager.loadClients()
            updateMetrics()
        } catch {
            print("Failed to load clients: \(error)")
        }
    }
    
    func saveClients() async {
        do {
            try await storageManager.saveClients(clients)
        } catch {
            print("Failed to save clients: \(error)")
        }
    }
    
    func addClient(name: String, siteURL: String) async {
        let client = Client(name: name, siteURL: siteURL)
        clients.append(client)
        
        // Create DNS record for client
        let subdomain = name.lowercased().replacingOccurrences(of: " ", with: "-")
        if let serverIP = UserDefaults.standard.string(forKey: "external_ip") {
            do {
                try await cloudflareService.createOrUpdateDNSRecord(
                    subdomain: subdomain,
                    ipAddress: serverIP,
                    port: 8321
                )
                
                // Update client with DNS record
                if let index = clients.firstIndex(where: { $0.id == client.id }) {
                    clients[index].dnsRecord = "\(subdomain).connect.elephunkie.com"
                }
            } catch {
                print("Failed to create DNS record: \(error)")
            }
        }
        
        await saveClients()
        updateMetrics()
    }
    
    func removeClient(_ client: Client) async {
        clients.removeAll { $0.id == client.id }
        await saveClients()
        updateMetrics()
    }
    
    func scanAllClients() async {
        for client in clients {
            await scanClient(client)
        }
    }
    
    func scanClient(_ client: Client) async {
        // Send scan request to client
        guard let url = URL(string: "\(client.siteURL)/wp-json/elephunkie/v1/scan") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(client.authToken, forHTTPHeaderField: "X-Auth-Token")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let scanData = try? JSONDecoder().decode(ScanResponse.self, from: data) {
                
                // Update client with scan results
                if let index = clients.firstIndex(where: { $0.id == client.id }) {
                    clients[index].wordPressVersion = scanData.wordpressVersion
                    clients[index].phpVersion = scanData.phpVersion
                    clients[index].plugins = scanData.plugins.map { Plugin(
                        name: $0.name,
                        slug: $0.slug,
                        version: $0.version,
                        updateAvailable: $0.updateAvailable,
                        isActive: $0.isActive
                    )}
                    clients[index].themes = scanData.themes.map { Theme(
                        name: $0.name,
                        slug: $0.slug,
                        version: $0.version,
                        updateAvailable: $0.updateAvailable,
                        isActive: $0.isActive
                    )}
                    clients[index].lastSeen = Date()
                    clients[index].status = determineClientStatus(for: clients[index])
                }
                
                await saveClients()
                updateMetrics()
            }
        } catch {
            print("Failed to scan client \(client.name): \(error)")
            
            // Mark client as offline
            if let index = clients.firstIndex(where: { $0.id == client.id }) {
                clients[index].status = .offline
            }
        }
    }
    
    func updateAllClients() async {
        for client in clients {
            let updates = client.plugins.filter { $0.updateAvailable != nil }
            if !updates.isEmpty {
                await updateClientPlugins(client, plugins: updates)
            }
        }
    }
    
    func updateClientPlugins(_ client: Client, plugins: [Plugin]) async {
        guard let url = URL(string: "\(client.siteURL)/wp-json/elephunkie/v1/update") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.authToken, forHTTPHeaderField: "X-Auth-Token")
        
        let updateRequest = UpdateRequest(
            type: "plugins",
            items: plugins.map { $0.slug }
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(updateRequest)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Rescan after update
                await scanClient(client)
            }
        } catch {
            print("Failed to update client \(client.name): \(error)")
        }
    }
    
    private func determineClientStatus(for client: Client) -> ClientStatus {
        // Check for critical issues
        if let metrics = client.healthMetrics {
            if metrics.errorCount > 10 || metrics.securityIssues > 0 {
                return .critical
            }
            if metrics.cpuUsage > 0.8 || metrics.memoryUsage > 0.8 {
                return .warning
            }
        }
        
        // Check for updates
        let hasUpdates = client.plugins.contains { $0.updateAvailable != nil } ||
                        client.themes.contains { $0.updateAvailable != nil }
        
        if hasUpdates {
            return .warning
        }
        
        return .healthy
    }
    
    private func updateMetrics() {
        pendingUpdates = clients.reduce(0) { count, client in
            count + client.plugins.filter { $0.updateAvailable != nil }.count +
                   client.themes.filter { $0.updateAvailable != nil }.count
        }
        
        // These would be populated from actual ticket and error log systems
        openTickets = 3
        unreadErrors = 5
    }
}

// Storage Manager
class StorageManager {
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let clientsFile: URL
    
    init() {
        clientsFile = documentsDirectory.appendingPathComponent("clients.json")
    }
    
    func loadClients() async throws -> [Client] {
        guard FileManager.default.fileExists(atPath: clientsFile.path) else {
            return []
        }
        
        let data = try Data(contentsOf: clientsFile)
        return try JSONDecoder().decode([Client].self, from: data)
    }
    
    func saveClients(_ clients: [Client]) async throws {
        let data = try JSONEncoder().encode(clients)
        try data.write(to: clientsFile)
    }
}

// Response Models
struct ScanResponse: Codable {
    let clientId: String
    let wordpressVersion: String
    let phpVersion: String
    let plugins: [PluginData]
    let themes: [ThemeData]
    let healthMetrics: HealthMetrics
    
    struct PluginData: Codable {
        let name: String
        let slug: String
        let version: String
        let updateAvailable: String?
        let isActive: Bool
        
        enum CodingKeys: String, CodingKey {
            case name, slug, version
            case updateAvailable = "update_available"
            case isActive = "is_active"
        }
    }
    
    struct ThemeData: Codable {
        let name: String
        let slug: String
        let version: String
        let updateAvailable: String?
        let isActive: Bool
        
        enum CodingKeys: String, CodingKey {
            case name, slug, version
            case updateAvailable = "update_available"
            case isActive = "is_active"
        }
    }
}

struct UpdateRequest: Codable {
    let type: String
    let items: [String]
}