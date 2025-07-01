import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var serverManager: LocalServerManager
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            switch appState.selectedView {
            case .dashboard:
                DashboardView()
            case .clients:
                ClientsView()
            case .updates:
                UpdatesView()
            case .tickets:
                TicketsView()
            case .reports:
                ReportsView()
            case .logs:
                LogsView()
            case .settings:
                SettingsView()
            }
        }
        #if os(macOS)
        .frame(minWidth: 1200, minHeight: 800)
        #endif
        .onAppear {
            Task {
                await appState.loadClients()
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var serverManager: LocalServerManager
    
    var body: some View {
        List(selection: $appState.selectedView) {
            Section("Overview") {
                Label("Dashboard", systemImage: "square.grid.3x3")
                    .tag(AppView.dashboard)
                
                Label("Clients", systemImage: "person.2")
                    .tag(AppView.clients)
                    .badge(appState.clients.count)
            }
            
            Section("Management") {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                    .tag(AppView.updates)
                    .badge(appState.pendingUpdates)
                
                Label("Tickets", systemImage: "ticket")
                    .tag(AppView.tickets)
                    .badge(appState.openTickets)
                
                Label("Reports", systemImage: "doc.text")
                    .tag(AppView.reports)
            }
            
            Section("System") {
                Label("Error Logs", systemImage: "exclamationmark.triangle")
                    .tag(AppView.logs)
                    .badge(appState.unreadErrors)
                
                Label("Settings", systemImage: "gear")
                    .tag(AppView.settings)
            }
            
            Spacer()
            
            Section {
                ServerStatusView()
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Elephunkie")
    }
}

struct ServerStatusView: View {
    @EnvironmentObject var serverManager: LocalServerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(serverManager.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(serverManager.isRunning ? "Server Running" : "Server Offline")
                    .font(.caption)
            }
            
            if serverManager.isRunning {
                Text(serverManager.serverAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !serverManager.externalIP.isEmpty {
                    Text("IP: \(serverManager.externalIP)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

enum AppView: Hashable {
    case dashboard
    case clients
    case updates
    case tickets
    case reports
    case logs
    case settings
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(LocalServerManager())
    }
}