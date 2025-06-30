import SwiftUI

struct ClientsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedClient: Client?
    @State private var showingAddClient = false
    @State private var showingPluginGenerator = false
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return appState.clients
        } else {
            return appState.clients.filter { client in
                client.name.localizedCaseInsensitiveContains(searchText) ||
                client.siteURL.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List(selection: $selectedClient) {
                ForEach(filteredClients) { client in
                    ClientRow(client: client)
                        .tag(client)
                        .contextMenu {
                            Button("Scan Now") {
                                Task {
                                    await appState.scanClient(client)
                                }
                            }
                            
                            Button("Generate Plugin") {
                                selectedClient = client
                                showingPluginGenerator = true
                            }
                            
                            Divider()
                            
                            Button("Open Admin", action: {
                                if let url = URL(string: "\(client.siteURL)/wp-admin") {
                                    #if os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #else
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            })
                            
                            Divider()
                            
                            Button("Remove", role: .destructive) {
                                Task {
                                    await appState.removeClient(client)
                                }
                            }
                        }
                }
            }
            .searchable(text: $searchText, prompt: "Search clients...")
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddClient = true
                    } label: {
                        Label("Add Client", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await appState.scanAllClients()
                        }
                    } label: {
                        Label("Scan All", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
            .sheet(isPresented: $showingPluginGenerator) {
                if let client = selectedClient {
                    PluginGeneratorView(client: client)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 400)
    }
}

struct ClientRow: View {
    let client: Client
    
    var body: some View {
        HStack {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            // Client Info
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.headline)
                
                Text(client.siteURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastSeen = client.lastSeen {
                    Text("Last seen: \(lastSeen.formatted(.relative(presentation: .abbreviated)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Metrics
            VStack(alignment: .trailing, spacing: 4) {
                if let wp = client.wordPressVersion {
                    Label(wp, systemImage: "w.circle")
                        .font(.caption)
                        .labelStyle(.titleOnly)
                }
                
                HStack(spacing: 16) {
                    // Plugin updates
                    if updateCount > 0 {
                        Label("\(updateCount)", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // Security issues
                    if let metrics = client.healthMetrics, metrics.securityIssues > 0 {
                        Label("\(metrics.securityIssues)", systemImage: "exclamationmark.shield")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var statusColor: Color {
        switch client.status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .offline: return .gray
        case .pending: return .blue
        }
    }
    
    var updateCount: Int {
        client.plugins.filter { $0.updateAvailable != nil }.count +
        client.themes.filter { $0.updateAvailable != nil }.count
    }
}

struct AddClientView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var clientName = ""
    @State private var siteURL = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client Information") {
                    TextField("Client Name", text: $clientName)
                        .textContentType(.organizationName)
                    
                    TextField("WordPress Site URL", text: $siteURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit {
                            // Clean up URL
                            if !siteURL.isEmpty && !siteURL.hasPrefix("http") {
                                siteURL = "https://\(siteURL)"
                            }
                        }
                }
                
                Section {
                    Text("After adding the client, you'll need to install the generated plugin on their WordPress site.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addClient()
                    }
                    .disabled(clientName.isEmpty || siteURL.isEmpty || isProcessing)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 300)
        #endif
    }
    
    func addClient() {
        isProcessing = true
        
        Task {
            await appState.addClient(name: clientName, siteURL: siteURL)
            dismiss()
        }
    }
}

struct PluginGeneratorView: View {
    let client: Client
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var pluginCode = ""
    @State private var instructions = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Plugin Code
                    GroupBox("Plugin Code") {
                        ScrollView(.horizontal) {
                            Text(pluginCode)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }
                        .frame(maxHeight: 300)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Installation Instructions
                    GroupBox("Installation Instructions") {
                        Text(instructions)
                            .font(.caption)
                            .textSelection(.enabled)
                            .padding()
                    }
                    
                    // Actions
                    HStack {
                        Button("Copy Plugin Code") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(pluginCode, forType: .string)
                            #else
                            UIPasteboard.general.string = pluginCode
                            #endif
                        }
                        
                        Button("Save to File") {
                            savePluginToFile()
                        }
                        
                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle("Plugin for \(client.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            generatePlugin()
        }
        #if os(macOS)
        .frame(width: 800, height: 600)
        #endif
    }
    
    func generatePlugin() {
        let hubEndpoint = UserDefaults.standard.string(forKey: "hub_endpoint") ?? 
                         "https://\(client.dnsRecord ?? "connect.elephunkie.com"):8321"
        
        pluginCode = PluginGenerator.generatePlugin(for: client, hubEndpoint: hubEndpoint)
        instructions = PluginGenerator.generateInstallInstructions(for: client, pluginContent: pluginCode)
    }
    
    func savePluginToFile() {
        let fileName = "elephunkie-\(client.name.lowercased().replacingOccurrences(of: " ", with: "-")).php"
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedContentTypes = [.phpScript]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try pluginCode.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
        }
        #else
        // iOS file saving would use document picker
        #endif
    }
}

struct ClientsView_Previews: PreviewProvider {
    static var previews: some View {
        ClientsView()
            .environmentObject(AppState())
    }
}