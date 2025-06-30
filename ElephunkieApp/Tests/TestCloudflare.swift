import Foundation

// Test script to verify Cloudflare credentials
class CloudflareTest {
    static func testCredentials() async {
        print("Testing Cloudflare API credentials...")
        
        let apiToken = "XspvHdYi9Y3YSI96_5sF3pYYb4O0nW1-69Z9K2vB"
        let zoneID = "f3830ecd755d9a9fce0706a76853bef3"
        
        // Test 1: Verify token by listing DNS records
        let url = URL(string: "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Credentials are valid!")
                    
                    // Parse and display existing records
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [[String: Any]] {
                        print("\nExisting DNS records:")
                        for record in result {
                            if let name = record["name"] as? String,
                               let type = record["type"] as? String,
                               let content = record["content"] as? String {
                                print("  - \(type): \(name) -> \(content)")
                            }
                        }
                    }
                } else {
                    print("❌ Invalid credentials or permissions")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("Error: \(errorData)")
                    }
                }
            }
        } catch {
            print("❌ Network error: \(error)")
        }
        
        // Test 2: Get zone details
        print("\nGetting zone details...")
        let zoneUrl = URL(string: "https://api.cloudflare.com/client/v4/zones/\(zoneID)")!
        
        var zoneRequest = URLRequest(url: zoneUrl)
        zoneRequest.httpMethod = "GET"
        zoneRequest.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: zoneRequest)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let name = result["name"] as? String {
                print("✅ Zone name: \(name)")
            }
        } catch {
            print("❌ Failed to get zone details: \(error)")
        }
    }
    
    static func testCreateRecord() async {
        print("\nTesting DNS record creation...")
        
        let apiToken = "XspvHdYi9Y3YSI96_5sF3pYYb4O0nW1-69Z9K2vB"
        let zoneID = "f3830ecd755d9a9fce0706a76853bef3"
        let testSubdomain = "test-client-\(Int.random(in: 1000...9999))"
        
        let cloudflare = CloudflareService(apiToken: apiToken, zoneID: zoneID)
        
        do {
            // Get current external IP
            let ipUrl = URL(string: "https://api.ipify.org")!
            let (ipData, _) = try await URLSession.shared.data(from: ipUrl)
            let externalIP = String(data: ipData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "127.0.0.1"
            
            print("External IP: \(externalIP)")
            print("Creating record: \(testSubdomain).connect.elephunkie.com -> \(externalIP)")
            
            try await cloudflare.createOrUpdateDNSRecord(
                subdomain: testSubdomain,
                ipAddress: externalIP,
                port: 8321
            )
            
            print("✅ Successfully created DNS record!")
            print("Test URL: https://\(testSubdomain).connect.elephunkie.com:8321")
            
        } catch {
            print("❌ Failed to create DNS record: \(error)")
        }
    }
}

// Run tests
Task {
    await CloudflareTest.testCredentials()
    await CloudflareTest.testCreateRecord()
}