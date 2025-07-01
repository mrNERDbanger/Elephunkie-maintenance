import Foundation

class CloudflareService {
    private let apiToken: String
    private let zoneID: String
    private let baseURL = "https://api.cloudflare.com/client/v4"
    
    init(apiToken: String, zoneID: String) {
        self.apiToken = apiToken
        self.zoneID = zoneID
    }
    
    func createOrUpdateDNSRecord(subdomain: String, ipAddress: String, port: Int) async throws {
        let recordName = "\(subdomain).connect.elephunkie.com"
        
        // First, check if record exists
        if let existingRecord = try await findDNSRecord(name: recordName) {
            // Update existing record
            try await updateDNSRecord(recordID: existingRecord.id, name: recordName, ipAddress: ipAddress)
        } else {
            // Create new record
            try await createDNSRecord(name: recordName, ipAddress: ipAddress)
        }
        
        // Also create SRV record for port if needed
        let srvName = "_elephunkie._tcp.\(subdomain).connect.elephunkie.com"
        try await createOrUpdateSRVRecord(name: srvName, target: recordName, port: port)
    }
    
    private func findDNSRecord(name: String) async throws -> DNSRecord? {
        let url = URL(string: "\(baseURL)/zones/\(zoneID)/dns_records?name=\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudflareError.requestFailed
        }
        
        let result = try JSONDecoder().decode(CloudflareResponse<[DNSRecord]>.self, from: data)
        return result.result.first
    }
    
    private func createDNSRecord(name: String, ipAddress: String) async throws {
        let url = URL(string: "\(baseURL)/zones/\(zoneID)/dns_records")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "type": "A",
            "name": name,
            "content": ipAddress,
            "ttl": 120,
            "proxied": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudflareError.requestFailed
        }
    }
    
    private func updateDNSRecord(recordID: String, name: String, ipAddress: String) async throws {
        let url = URL(string: "\(baseURL)/zones/\(zoneID)/dns_records/\(recordID)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "type": "A",
            "name": name,
            "content": ipAddress,
            "ttl": 120,
            "proxied": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudflareError.requestFailed
        }
    }
    
    private func createOrUpdateSRVRecord(name: String, target: String, port: Int) async throws {
        // SRV record format: priority weight port target
        let content = "0 1 \(port) \(target)"
        
        if let existingRecord = try await findDNSRecord(name: name) {
            try await updateSRVRecord(recordID: existingRecord.id, name: name, content: content)
        } else {
            try await createSRVRecord(name: name, content: content)
        }
    }
    
    private func createSRVRecord(name: String, content: String) async throws {
        let url = URL(string: "\(baseURL)/zones/\(zoneID)/dns_records")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "type": "SRV",
            "name": name,
            "content": content,
            "ttl": 120
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudflareError.requestFailed
        }
    }
    
    private func updateSRVRecord(recordID: String, name: String, content: String) async throws {
        let url = URL(string: "\(baseURL)/zones/\(zoneID)/dns_records/\(recordID)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "type": "SRV",
            "name": name,
            "content": content,
            "ttl": 120
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudflareError.requestFailed
        }
    }
}

struct CloudflareResponse<T: Codable>: Codable {
    let success: Bool
    let errors: [CloudflareError]?
    let result: T
}

struct DNSRecord: Codable {
    let id: String
    let type: String
    let name: String
    let content: String
}

enum CloudflareError: Error {
    case requestFailed
    case invalidResponse
    case recordNotFound
}