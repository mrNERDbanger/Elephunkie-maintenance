import SwiftUI

struct LogsView: View {
    @StateObject private var logManager = LogManager()
    @State private var selectedLogLevel: LogLevel = .all
    @State private var searchText = ""
    @State private var selectedTimeRange: TimeRange = .today
    
    var filteredLogs: [LogEntry] {
        var logs = logManager.logs
        
        // Filter by level
        if selectedLogLevel != .all {
            logs = logs.filter { $0.level == selectedLogLevel }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { log in
                log.message.localizedCaseInsensitiveContains(searchText) ||
                log.source.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by time range
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeRange {
        case .today:
            logs = logs.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            logs = logs.filter { $0.timestamp >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            logs = logs.filter { $0.timestamp >= monthAgo }
        case .all:
            break
        }
        
        return logs.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                VStack(spacing: 12) {
                    HStack {
                        Picker("Level", selection: $selectedLogLevel) {
                            ForEach(LogLevel.allCases, id: \.self) { level in
                                Label(level.displayName, systemImage: level.icon)
                                    .tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.displayName)
                                    .tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    SearchField(text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Log Entries
                List {
                    if filteredLogs.isEmpty {
                        ContentUnavailableView(
                            "No Logs Found",
                            systemImage: "doc.text",
                            description: Text("No log entries match your current filters")
                        )
                    } else {
                        ForEach(filteredLogs) { log in
                            LogEntryRow(log: log)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Error Logs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Mark All as Read") {
                            logManager.markAllAsRead()
                        }
                        
                        Button("Export Logs") {
                            exportLogs()
                        }
                        
                        Divider()
                        
                        Button("Clear Old Logs", role: .destructive) {
                            logManager.clearOldLogs()
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        logManager.refreshLogs()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            logManager.loadLogs()
        }
    }
    
    func exportLogs() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "elephunkie-logs-\(Date().formatted(.iso8601.day().month().year())).txt"
        savePanel.allowedContentTypes = [.plainText]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                logManager.exportLogs(to: url, logs: filteredLogs)
            }
        }
        #endif
    }
}

struct LogEntryRow: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Level indicator
                Image(systemName: log.level.icon)
                    .foregroundColor(log.level.color)
                    .frame(width: 20)
                
                // Source
                Text(log.source)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                
                Spacer()
                
                // Timestamp
                Text(log.timestamp.formatted(.relative(presentation: .abbreviated)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Unread indicator
                if !log.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Message
            Text(log.message)
                .font(.body)
                .lineLimit(isExpanded ? nil : 2)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            
            // Additional details when expanded
            if isExpanded && (!log.details.isEmpty || !log.stackTrace.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    if !log.details.isEmpty {
                        Text("Details:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(log.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    if !log.stackTrace.isEmpty {
                        Text("Stack Trace:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(log.stackTrace)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

struct SearchField: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search logs...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Models

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    let details: String
    let stackTrace: String
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        source: String,
        message: String,
        details: String = "",
        stackTrace: String = "",
        isRead: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.message = message
        self.details = details
        self.stackTrace = stackTrace
        self.isRead = isRead
    }
}

enum LogLevel: String, Codable, CaseIterable {
    case all = "all"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "doc.text"
        case .error: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        case .debug: return "ladybug"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .purple
        }
    }
}

enum TimeRange: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .all: return "All Time"
        }
    }
}

@MainActor
class LogManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    
    private let storageURL = AppConfig.logsDirectory.appendingPathComponent("error_logs.json")
    
    init() {
        loadLogs()
        createSampleLogs()
    }
    
    func loadLogs() {
        do {
            try FileManager.default.createDirectory(at: AppConfig.logsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create logs directory: \(error)")
        }
        
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            logs = try JSONDecoder().decode([LogEntry].self, from: data)
        } catch {
            print("Failed to load logs: \(error)")
        }
    }
    
    func saveLogs() {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }
    
    func addLog(_ log: LogEntry) {
        logs.insert(log, at: 0) // Insert at beginning for newest first
        
        // Keep only last 1000 logs
        if logs.count > 1000 {
            logs = Array(logs.prefix(1000))
        }
        
        saveLogs()
    }
    
    func markAllAsRead() {
        for index in logs.indices {
            logs[index].isRead = true
        }
        saveLogs()
    }
    
    func clearOldLogs() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        logs.removeAll { $0.timestamp < thirtyDaysAgo }
        saveLogs()
    }
    
    func refreshLogs() {
        // In a real implementation, this would fetch new logs from clients
        loadLogs()
    }
    
    func exportLogs(to url: URL, logs: [LogEntry]) {
        var content = "Elephunkie Error Logs Export\n"
        content += "Generated: \(Date().formatted(.dateTime))\n\n"
        
        for log in logs {
            content += "[\(log.timestamp.formatted(.dateTime))] \(log.level.displayName.uppercased()) - \(log.source)\n"
            content += "\(log.message)\n"
            
            if !log.details.isEmpty {
                content += "Details: \(log.details)\n"
            }
            
            if !log.stackTrace.isEmpty {
                content += "Stack Trace:\n\(log.stackTrace)\n"
            }
            
            content += "\n" + String(repeating: "-", count: 50) + "\n\n"
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("Logs exported to: \(url)")
        } catch {
            print("Failed to export logs: \(error)")
        }
    }
    
    private func createSampleLogs() {
        guard logs.isEmpty else { return }
        
        let sampleLogs = [
            LogEntry(
                timestamp: Date().addingTimeInterval(-300),
                level: .error,
                source: "Client A",
                message: "PHP Fatal Error: Cannot redeclare function wp_head()",
                details: "Error occurred in wp-includes/general-template.php on line 2834",
                stackTrace: "#0 wp-includes/general-template.php(2834): wp_head()\n#1 wp-content/themes/theme/header.php(15): get_header()"
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-1800),
                level: .warning,
                source: "Client B",
                message: "Plugin conflict detected: WooCommerce and Advanced Custom Fields",
                details: "Potential incompatibility between WooCommerce 8.0 and ACF Pro 6.1"
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-3600),
                level: .info,
                source: "System",
                message: "Successfully updated 5 plugins across all monitored sites"
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-7200),
                level: .error,
                source: "Client C",
                message: "Database connection failed",
                details: "MySQL server has gone away"
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-14400),
                level: .warning,
                source: "Client A",
                message: "Disk space running low: 85% usage",
                details: "Current usage: 4.2GB / 5GB available"
            )
        ]
        
        logs = sampleLogs
        saveLogs()
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView()
    }
}