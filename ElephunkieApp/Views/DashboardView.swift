import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Cards
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Total Clients",
                        value: "\(appState.clients.count)",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    
                    SummaryCard(
                        title: "Healthy Sites",
                        value: "\(healthySites)",
                        icon: "checkmark.shield.fill",
                        color: .green
                    )
                    
                    SummaryCard(
                        title: "Updates Available",
                        value: "\(appState.pendingUpdates)",
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange
                    )
                    
                    SummaryCard(
                        title: "Critical Issues",
                        value: "\(criticalIssues)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // Client Status Overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Client Status Overview")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if #available(iOS 16.0, macOS 13.0, *) {
                        Chart(statusData) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                        Spacer()
                        Button("View All") {
                            appState.selectedView = .logs
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(recentActivities) { activity in
                            ActivityRow(activity: activity)
                            if activity != recentActivities.last {
                                Divider()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        QuickActionButton(
                            title: "Scan All Sites",
                            icon: "magnifyingglass",
                            action: scanAllSites
                        )
                        
                        QuickActionButton(
                            title: "Update All",
                            icon: "arrow.triangle.2.circlepath",
                            action: updateAll
                        )
                        
                        QuickActionButton(
                            title: "Generate Report",
                            icon: "doc.text",
                            action: generateReport
                        )
                        
                        QuickActionButton(
                            title: "Add Client",
                            icon: "plus.circle",
                            action: addClient
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        #if os(macOS)
        .navigationSubtitle("\(Date.now.formatted(date: .abbreviated, time: .shortened))")
        #endif
    }
    
    var healthySites: Int {
        appState.clients.filter { $0.status == .healthy }.count
    }
    
    var criticalIssues: Int {
        appState.clients.filter { $0.status == .critical }.count
    }
    
    var statusData: [(status: ClientStatus, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: appState.clients) { $0.status }
        return ClientStatus.allCases.compactMap { status in
            let count = grouped[status]?.count ?? 0
            guard count > 0 else { return nil }
            let color: Color = {
                switch status {
                case .healthy: return .green
                case .warning: return .yellow
                case .critical: return .red
                case .offline: return .gray
                case .pending: return .blue
                }
            }()
            return (status, count, color)
        }
    }
    
    var recentActivities: [Activity] {
        // Mock data - replace with actual activity log
        [
            Activity(id: UUID(), type: .update, message: "Updated plugins on ClientA", timestamp: Date().addingTimeInterval(-300)),
            Activity(id: UUID(), type: .scan, message: "Completed scan of ClientB", timestamp: Date().addingTimeInterval(-1800)),
            Activity(id: UUID(), type: .error, message: "Critical error on ClientC", timestamp: Date().addingTimeInterval(-3600)),
            Activity(id: UUID(), type: .registration, message: "New client registered: ClientD", timestamp: Date().addingTimeInterval(-7200))
        ]
    }
    
    func scanAllSites() {
        Task {
            await appState.scanAllClients()
        }
    }
    
    func updateAll() {
        Task {
            await appState.updateAllClients()
        }
    }
    
    func generateReport() {
        appState.showReportGenerator = true
    }
    
    func addClient() {
        appState.showAddClient = true
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack {
            Image(systemName: activity.type.icon)
                .foregroundColor(activity.type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.message)
                    .font(.subheadline)
                Text(activity.timestamp.formatted(.relative(presentation: .abbreviated)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

struct Activity: Identifiable {
    let id: UUID
    let type: ActivityType
    let message: String
    let timestamp: Date
}

enum ActivityType {
    case update, scan, error, registration
    
    var icon: String {
        switch self {
        case .update: return "arrow.triangle.2.circlepath"
        case .scan: return "magnifyingglass"
        case .error: return "exclamationmark.triangle"
        case .registration: return "person.badge.plus"
        }
    }
    
    var color: Color {
        switch self {
        case .update: return .blue
        case .scan: return .green
        case .error: return .red
        case .registration: return .purple
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DashboardView()
                .environmentObject(AppState())
        }
    }
}