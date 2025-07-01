import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var serverManager: LocalServerManager
    @AppStorage("cloudflare_api_token") private var cloudflareAPIToken = ""
    @AppStorage("cloudflare_zone_id") private var cloudflareZoneID = ""
    @AppStorage("notification_enabled") private var notificationsEnabled = true
    @AppStorage("auto_update_enabled") private var autoUpdateEnabled = false
    @AppStorage("scan_interval") private var scanInterval = 24.0
    @AppStorage("backup_retention_days") private var backupRetentionDays = 30.0
    
    @State private var showingAPITokenInfo = false
    @State private var showingExportData = false
    @State private var showingImportData = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Server Configuration
                Section("Server Configuration") {
                    HStack {
                        Label("Server Status", systemImage: "server.rack")
                        Spacer()
                        
                        HStack {
                            Circle()
                                .fill(serverManager.isRunning ? .green : .red)
                                .frame(width: 8, height: 8)
                            
                            Text(serverManager.isRunning ? "Running" : "Stopped")
                                .foregroundColor(serverManager.isRunning ? .green : .red)
                        }
                    }
                    
                    if serverManager.isRunning {
                        LabeledContent("Local Address", value: serverManager.serverAddress)
                        
                        if !serverManager.externalIP.isEmpty {
                            LabeledContent("External IP", value: serverManager.externalIP)
                        }
                    }
                    
                    Button(serverManager.isRunning ? "Stop Server" : "Start Server") {
                        Task {
                            if serverManager.isRunning {
                                await serverManager.stopServer()
                            } else {
                                await serverManager.startServer()
                            }
                        }
                    }
                    .foregroundColor(serverManager.isRunning ? .red : .green)
                }
                
                // Cloudflare Configuration
                Section("Cloudflare Configuration") {
                    SecureField("API Token", text: $cloudflareAPIToken)
                        .textContentType(.password)
                    
                    TextField("Zone ID", text: $cloudflareZoneID)
                        .textContentType(.organizationName)
                    
                    Button("Test Connection") {
                        testCloudflareConnection()
                    }
                    .disabled(cloudflareAPIToken.isEmpty || cloudflareZoneID.isEmpty)
                    
                    Button("API Token Help") {
                        showingAPITokenInfo = true
                    }
                    .foregroundColor(.blue)
                }
                
                // Monitoring Settings
                Section("Monitoring") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    
                    Toggle("Auto-Update Plugins", isOn: $autoUpdateEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scan Interval")
                            Spacer()
                            Text("\(Int(scanInterval)) hours")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $scanInterval, in: 1...72, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Log Retention")
                            Spacer()
                            Text("\(Int(backupRetentionDays)) days")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $backupRetentionDays, in: 7...365, step: 1)
                    }
                }
                
                // Data Management
                Section("Data Management") {
                    Button("Export Data") {
                        showingExportData = true
                    }
                    
                    Button("Import Data") {
                        showingImportData = true
                    }
                    
                    Button("Reset All Settings", role: .destructive) {
                        resetAllSettings()
                    }
                }
                
                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "2024.1")
                    
                    HStack {
                        Text("Clients")
                        Spacer()
                        Text("\(appState.clients.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("View Logs Directory") {
                        openLogsDirectory()
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/mrNERDbanger/Elephunkie-maintenance")!)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAPITokenInfo) {
            APITokenHelpView()
        }
        .fileExporter(
            isPresented: $showingExportData,
            document: ExportDocument(),
            contentType: .json,
            defaultFilename: "elephunkie-export-\(Date().formatted(.iso8601.day().month().year()))"
        ) { result in
            switch result {
            case .success(let url):
                print("Data exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingImportData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importData(from: url)
                }
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
    }
    
    func testCloudflareConnection() {
        Task {
            // Test the Cloudflare connection
            print("Testing Cloudflare connection...")
            // Implementation would test the API token and zone ID
        }
    }
    
    func resetAllSettings() {
        // Reset UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "cloudflare_api_token")
        defaults.removeObject(forKey: "cloudflare_zone_id")
        defaults.removeObject(forKey: "notification_enabled")
        defaults.removeObject(forKey: "auto_update_enabled")
        defaults.removeObject(forKey: "scan_interval")
        defaults.removeObject(forKey: "backup_retention_days")
        
        // Reset to default values
        cloudflareAPIToken = ""
        cloudflareZoneID = ""
        notificationsEnabled = true
        autoUpdateEnabled = false
        scanInterval = 24.0
        backupRetentionDays = 30.0
    }
    
    func openLogsDirectory() {
        #if os(macOS)
        NSWorkspace.shared.open(AppConfig.logsDirectory)
        #endif
    }
    
    func importData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(ExportData.self, from: data)
            
            // Import clients
            Task {
                appState.clients = exportData.clients
                await appState.saveClients()
            }
            
            print("Data imported successfully")
        } catch {
            print("Failed to import data: \(error)")
        }
    }
}

struct APITokenHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Get Your Cloudflare API Token")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        StepView(
                            number: 1,
                            title: "Go to Cloudflare Dashboard",
                            description: "Visit cloudflare.com and log into your account"
                        )
                        
                        StepView(
                            number: 2,
                            title: "Navigate to API Tokens",
                            description: "Go to My Profile > API Tokens"
                        )
                        
                        StepView(
                            number: 3,
                            title: "Create Token",
                            description: "Click 'Create Token' and select 'Custom token'"
                        )
                        
                        StepView(
                            number: 4,
                            title: "Set Permissions",
                            description: """
                            Add these permissions:
                            • Zone:DNS:Edit
                            • Zone:Zone Settings:Read
                            • Zone:Zone:Read
                            """
                        )
                        
                        StepView(
                            number: 5,
                            title: "Zone Resources",
                            description: "Include: Specific zone > [your domain]"
                        )
                        
                        StepView(
                            number: 6,
                            title: "Get Zone ID",
                            description: "From your domain's overview page, copy the Zone ID from the right sidebar"
                        )
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Security Note", systemImage: "exclamationmark.shield")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("Keep your API token secure and never share it publicly. This token allows access to your DNS settings.")
                                .font(.caption)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("API Token Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Export/Import

struct ExportData: Codable {
    let clients: [Client]
    let exportDate: Date
    let version: String
    
    init(clients: [Client]) {
        self.clients = clients
        self.exportDate = Date()
        self.version = "1.0.0"
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init() {
        // This would contain the actual export data
        let exportData = ExportData(clients: [])
        self.data = (try? JSONEncoder().encode(exportData)) ?? Data()
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(LocalServerManager())
    }
}