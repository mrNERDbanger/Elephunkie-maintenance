import SwiftUI

struct UpdatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedUpdateType: UpdateType = .all
    @State private var showingUpdateDetails = false
    @State private var selectedUpdate: UpdateItem?
    @State private var isUpdating = false
    
    var filteredUpdates: [UpdateItem] {
        let allUpdates = collectAllUpdates()
        
        switch selectedUpdateType {
        case .all:
            return allUpdates
        case .plugins:
            return allUpdates.filter { $0.type == .plugin }
        case .themes:
            return allUpdates.filter { $0.type == .theme }
        case .core:
            return allUpdates.filter { $0.type == .core }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Update Summary Header
                UpdateSummaryHeader(updates: collectAllUpdates())
                
                // Filter Tabs
                Picker("Update Type", selection: $selectedUpdateType) {
                    ForEach(UpdateType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Updates List
                List {
                    if filteredUpdates.isEmpty {
                        ContentUnavailableView(
                            "No Updates Available",
                            systemImage: "checkmark.circle",
                            description: Text("All your sites are up to date!")
                        )
                    } else {
                        ForEach(filteredUpdates) { update in
                            UpdateRow(update: update)
                                .onTapGesture {
                                    selectedUpdate = update
                                    showingUpdateDetails = true
                                }
                                .contextMenu {
                                    Button("Update Now") {
                                        updateSingle(update)
                                    }
                                    
                                    Button("View Changelog") {
                                        viewChangelog(update)
                                    }
                                    
                                    Button("Skip This Version") {
                                        skipVersion(update)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Updates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        updateAll()
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("Update All", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isUpdating || filteredUpdates.isEmpty)
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await appState.scanAllClients()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingUpdateDetails) {
                if let update = selectedUpdate {
                    UpdateDetailView(update: update)
                }
            }
        }
    }
    
    func collectAllUpdates() -> [UpdateItem] {
        var updates: [UpdateItem] = []
        
        for client in appState.clients {
            // Plugin updates
            for plugin in client.plugins where plugin.updateAvailable != nil {
                updates.append(UpdateItem(
                    id: UUID(),
                    clientID: client.id,
                    clientName: client.name,
                    type: .plugin,
                    name: plugin.name,
                    currentVersion: plugin.version,
                    availableVersion: plugin.updateAvailable!,
                    slug: plugin.slug,
                    priority: determinePriority(for: plugin.name)
                ))
            }
            
            // Theme updates
            for theme in client.themes where theme.updateAvailable != nil {
                updates.append(UpdateItem(
                    id: UUID(),
                    clientID: client.id,
                    clientName: client.name,
                    type: .theme,
                    name: theme.name,
                    currentVersion: theme.version,
                    availableVersion: theme.updateAvailable!,
                    slug: theme.slug,
                    priority: .medium
                ))
            }
            
            // WordPress core updates (mock - would be detected from scan)
            // This would come from the WordPress scan results
        }
        
        return updates.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    func determinePriority(for pluginName: String) -> UpdatePriority {
        let securityPlugins = ["wordfence", "security", "akismet", "jetpack"]
        let backupPlugins = ["backup", "updraft", "duplicator"]
        
        let lowerName = pluginName.lowercased()
        
        if securityPlugins.contains(where: { lowerName.contains($0) }) {
            return .critical
        } else if backupPlugins.contains(where: { lowerName.contains($0) }) {
            return .high
        } else {
            return .medium
        }
    }
    
    func updateAll() {
        isUpdating = true
        
        Task {
            await appState.updateAllClients()
            isUpdating = false
        }
    }
    
    func updateSingle(_ update: UpdateItem) {
        guard let client = appState.clients.first(where: { $0.id == update.clientID }) else { return }
        
        Task {
            switch update.type {
            case .plugin:
                if let plugin = client.plugins.first(where: { $0.slug == update.slug }) {
                    await appState.updateClientPlugins(client, plugins: [plugin])
                }
            case .theme:
                // Implementation for theme updates
                break
            case .core:
                // Implementation for core updates
                break
            }
        }
    }
    
    func viewChangelog(_ update: UpdateItem) {
        // Open changelog URL if available
        let changelogURL = "https://wordpress.org/plugins/\(update.slug)/#developers"
        if let url = URL(string: changelogURL) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func skipVersion(_ update: UpdateItem) {
        // Add to skipped versions list
        UserDefaults.standard.set([update.availableVersion], forKey: "skipped_versions_\(update.slug)")
    }
}

struct UpdateSummaryHeader: View {
    let updates: [UpdateItem]
    
    var criticalCount: Int { updates.filter { $0.priority == .critical }.count }
    var highCount: Int { updates.filter { $0.priority == .high }.count }
    var mediumCount: Int { updates.filter { $0.priority == .medium }.count }
    
    var body: some View {
        HStack(spacing: 20) {
            UpdateCountCard(
                count: criticalCount,
                title: "Critical",
                color: .red
            )
            
            UpdateCountCard(
                count: highCount,
                title: "High Priority",
                color: .orange
            )
            
            UpdateCountCard(
                count: mediumCount,
                title: "Medium",
                color: .blue
            )
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct UpdateCountCard: View {
    let count: Int
    let title: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

struct UpdateRow: View {
    let update: UpdateItem
    
    var body: some View {
        HStack {
            // Priority Indicator
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)
            
            // Update Icon
            Image(systemName: update.type.icon)
                .foregroundColor(update.type.color)
                .frame(width: 24)
            
            // Update Info
            VStack(alignment: .leading, spacing: 4) {
                Text(update.name)
                    .font(.headline)
                
                Text(update.clientName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("v\(update.currentVersion)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("v\(update.availableVersion)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Priority Badge
            Text(update.priority.displayName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.2))
                .foregroundColor(priorityColor)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
    
    var priorityColor: Color {
        switch update.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

struct UpdateDetailView: View {
    let update: UpdateItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(update.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(update.clientName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Version Info
                    GroupBox("Version Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Current Version:")
                                Spacer()
                                Text("v\(update.currentVersion)")
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Available Version:")
                                Spacer()
                                Text("v\(update.availableVersion)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Priority:")
                                Spacer()
                                Text(update.priority.displayName)
                                    .fontWeight(.medium)
                                    .foregroundColor(priorityColor)
                            }
                        }
                        .padding()
                    }
                    
                    // Actions
                    GroupBox("Actions") {
                        VStack(spacing: 12) {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Install Update")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            HStack(spacing: 12) {
                                Button("View Changelog") {}
                                    .buttonStyle(.bordered)
                                
                                Button("Skip Version") {}
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Update Details")
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
    
    var priorityColor: Color {
        switch update.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Models

struct UpdateItem: Identifiable {
    let id: UUID
    let clientID: UUID
    let clientName: String
    let type: UpdateItemType
    let name: String
    let currentVersion: String
    let availableVersion: String
    let slug: String
    let priority: UpdatePriority
}

enum UpdateType: CaseIterable {
    case all, plugins, themes, core
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .plugins: return "Plugins"
        case .themes: return "Themes"
        case .core: return "WordPress"
        }
    }
}

enum UpdateItemType {
    case plugin, theme, core
    
    var icon: String {
        switch self {
        case .plugin: return "puzzlepiece.extension"
        case .theme: return "paintbrush"
        case .core: return "w.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .plugin: return .blue
        case .theme: return .purple
        case .core: return .orange
        }
    }
}

enum UpdatePriority: Int, CaseIterable {
    case critical = 0
    case high = 1
    case medium = 2
    case low = 3
    
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

struct UpdatesView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatesView()
            .environmentObject(AppState())
    }
}