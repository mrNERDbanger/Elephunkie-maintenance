import Foundation

struct Report: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: ReportType
    var summary: String
    var clientCount: Int
    var updatesPerformed: Int
    var issuesResolved: Int
    var createdAt: Date
    var periodStart: Date
    var periodEnd: Date
    var sections: [ReportSection]
    var customNotes: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        type: ReportType,
        summary: String = "",
        clientCount: Int = 0,
        updatesPerformed: Int = 0,
        issuesResolved: Int = 0,
        createdAt: Date = Date(),
        periodStart: Date,
        periodEnd: Date,
        sections: [ReportSection] = [],
        customNotes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.summary = summary
        self.clientCount = clientCount
        self.updatesPerformed = updatesPerformed
        self.issuesResolved = issuesResolved
        self.createdAt = createdAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.sections = sections
        self.customNotes = customNotes
    }
}

struct ReportSection: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var sectionType: ReportSectionType
    var data: [String: String] // Key-value pairs for structured data
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        sectionType: ReportSectionType,
        data: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sectionType = sectionType
        self.data = data
    }
}

enum ReportSectionType: String, Codable, CaseIterable {
    case summary = "summary"
    case updates = "updates"
    case security = "security"
    case performance = "performance"
    case incidents = "incidents"
    case recommendations = "recommendations"
    
    var displayName: String {
        switch self {
        case .summary: return "Summary"
        case .updates: return "Updates"
        case .security: return "Security"
        case .performance: return "Performance"
        case .incidents: return "Incidents"
        case .recommendations: return "Recommendations"
        }
    }
}

@MainActor
class ReportManager: ObservableObject {
    @Published var reports: [Report] = []
    
    private let storageURL = AppConfig.documentsDirectory.appendingPathComponent("reports.json")
    
    init() {
        loadReports()
        createSampleReports()
    }
    
    func loadReports() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            reports = try JSONDecoder().decode([Report].self, from: data)
        } catch {
            print("Failed to load reports: \(error)")
        }
    }
    
    func saveReports() {
        do {
            let data = try JSONEncoder().encode(reports)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save reports: \(error)")
        }
    }
    
    func addReport(_ report: Report) {
        reports.insert(report, at: 0) // Insert at beginning for newest first
        saveReports()
    }
    
    func deleteReport(_ report: Report) {
        reports.removeAll { $0.id == report.id }
        saveReports()
    }
    
    func duplicateReport(_ report: Report) {
        var duplicatedReport = report
        duplicatedReport.id = UUID()
        duplicatedReport.title = "\(report.title) (Copy)"
        duplicatedReport.createdAt = Date()
        
        addReport(duplicatedReport)
    }
    
    func generateReport(
        title: String,
        type: ReportType,
        clientIDs: [UUID],
        clients: [Client],
        includeUpdates: Bool,
        includeSecurityIssues: Bool,
        includePerformanceMetrics: Bool,
        customNotes: String
    ) async -> Report {
        
        let filteredClients = clients.filter { clientIDs.contains($0.id) }
        
        // Calculate period based on report type
        let calendar = Calendar.current
        let now = Date()
        let (periodStart, periodEnd) = calculateReportPeriod(type: type, date: now)
        
        // Generate summary
        let summary = generateSummary(for: filteredClients, period: type)
        
        // Calculate metrics
        let updatesCount = calculateUpdatesPerformed(for: filteredClients)
        let issuesCount = calculateIssuesResolved(for: filteredClients)
        
        // Generate sections
        var sections: [ReportSection] = []
        
        if includeUpdates {
            sections.append(generateUpdatesSection(for: filteredClients))
        }
        
        if includeSecurityIssues {
            sections.append(generateSecuritySection(for: filteredClients))
        }
        
        if includePerformanceMetrics {
            sections.append(generatePerformanceSection(for: filteredClients))
        }
        
        let report = Report(
            title: title,
            type: type,
            summary: summary,
            clientCount: filteredClients.count,
            updatesPerformed: updatesCount,
            issuesResolved: issuesCount,
            periodStart: periodStart,
            periodEnd: periodEnd,
            sections: sections,
            customNotes: customNotes.isEmpty ? nil : customNotes
        )
        
        addReport(report)
        return report
    }
    
    private func calculateReportPeriod(type: ReportType, date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        
        switch type {
        case .monthly:
            let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
            let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
            return (startOfMonth, endOfMonth)
            
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.end ?? date
            return (startOfWeek, endOfWeek)
            
        case .custom:
            // For custom reports, use the last 30 days
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: date) ?? date
            return (thirtyDaysAgo, date)
        }
    }
    
    private func generateSummary(for clients: [Client], period: ReportType) -> String {
        let healthyCount = clients.filter { $0.status == .healthy }.count
        let warningCount = clients.filter { $0.status == .warning }.count
        let criticalCount = clients.filter { $0.status == .critical }.count
        
        var summary = "During this \(period.displayName.lowercased()) period, we monitored \(clients.count) client site(s). "
        
        if healthyCount > 0 {
            summary += "\(healthyCount) site(s) maintained healthy status. "
        }
        
        if warningCount > 0 {
            summary += "\(warningCount) site(s) required attention with minor issues. "
        }
        
        if criticalCount > 0 {
            summary += "\(criticalCount) site(s) experienced critical issues that were addressed. "
        }
        
        return summary
    }
    
    private func calculateUpdatesPerformed(for clients: [Client]) -> Int {
        // This would typically come from actual update logs
        // For now, simulate based on available updates
        return clients.reduce(0) { total, client in
            total + client.plugins.filter { $0.updateAvailable != nil }.count +
                   client.themes.filter { $0.updateAvailable != nil }.count
        }
    }
    
    private func calculateIssuesResolved(for clients: [Client]) -> Int {
        // This would come from ticket system
        return clients.reduce(0) { total, client in
            total + (client.healthMetrics?.securityIssues ?? 0)
        }
    }
    
    private func generateUpdatesSection(for clients: [Client]) -> ReportSection {
        var content = "Updates Performed:\n\n"
        
        for client in clients {
            let pluginUpdates = client.plugins.filter { $0.updateAvailable != nil }
            let themeUpdates = client.themes.filter { $0.updateAvailable != nil }
            
            if !pluginUpdates.isEmpty || !themeUpdates.isEmpty {
                content += "**\(client.name)**\n"
                
                if !pluginUpdates.isEmpty {
                    content += "• Plugins: \(pluginUpdates.map { $0.name }.joined(separator: ", "))\n"
                }
                
                if !themeUpdates.isEmpty {
                    content += "• Themes: \(themeUpdates.map { $0.name }.joined(separator: ", "))\n"
                }
                
                content += "\n"
            }
        }
        
        return ReportSection(
            title: "Updates Performed",
            content: content,
            sectionType: .updates
        )
    }
    
    private func generateSecuritySection(for clients: [Client]) -> ReportSection {
        var content = "Security Status:\n\n"
        
        for client in clients {
            if let metrics = client.healthMetrics {
                content += "**\(client.name)**\n"
                content += "• Security Issues: \(metrics.securityIssues)\n"
                
                if metrics.securityIssues == 0 {
                    content += "• Status: ✅ No security issues detected\n"
                } else {
                    content += "• Status: ⚠️ Issues requiring attention\n"
                }
                
                content += "\n"
            }
        }
        
        return ReportSection(
            title: "Security Analysis",
            content: content,
            sectionType: .security
        )
    }
    
    private func generatePerformanceSection(for clients: [Client]) -> ReportSection {
        var content = "Performance Metrics:\n\n"
        
        for client in clients {
            if let metrics = client.healthMetrics {
                content += "**\(client.name)**\n"
                content += "• CPU Usage: \(String(format: "%.1f", metrics.cpuUsage * 100))%\n"
                content += "• Memory Usage: \(String(format: "%.1f", metrics.memoryUsage * 100))%\n"
                content += "• Disk Usage: \(String(format: "%.1f", metrics.diskUsage * 100))%\n"
                content += "• Uptime: \(formatUptime(metrics.uptime))\n\n"
            }
        }
        
        return ReportSection(
            title: "Performance Metrics",
            content: content,
            sectionType: .performance
        )
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        return "\(days) days, \(hours) hours"
    }
    
    func exportReportAsPDF(_ report: Report, to url: URL) {
        // PDF generation implementation
        let htmlContent = generateHTML(for: report)
        
        // Convert HTML to PDF (simplified implementation)
        // In a real app, you'd use PDFKit or similar
        do {
            try htmlContent.write(to: url.appendingPathExtension("html"), atomically: true, encoding: .utf8)
            print("Report exported as HTML to: \(url)")
        } catch {
            print("Failed to export report: \(error)")
        }
    }
    
    func exportReportAsHTML(_ report: Report, to url: URL) {
        let htmlContent = generateHTML(for: report)
        
        do {
            try htmlContent.write(to: url, atomically: true, encoding: .utf8)
            print("Report exported as HTML to: \(url)")
        } catch {
            print("Failed to export report: \(error)")
        }
    }
    
    private func generateHTML(for report: Report) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(report.title)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
                h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
                h2 { color: #34495e; margin-top: 30px; }
                .metrics { display: flex; gap: 30px; margin: 20px 0; }
                .metric { text-align: center; }
                .metric-value { font-size: 24px; font-weight: bold; color: #3498db; }
                .section { margin: 30px 0; padding: 20px; background: #f8f9fa; border-radius: 5px; }
                .date { color: #7f8c8d; font-size: 14px; }
            </style>
        </head>
        <body>
            <h1>\(report.title)</h1>
            <p class="date">Generated: \(report.createdAt.formatted(.dateTime))</p>
            <p class="date">Period: \(report.periodStart.formatted(.dateTime.month().day().year())) - \(report.periodEnd.formatted(.dateTime.month().day().year()))</p>
            
            <div class="metrics">
                <div class="metric">
                    <div class="metric-value">\(report.clientCount)</div>
                    <div>Clients</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(report.updatesPerformed)</div>
                    <div>Updates</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(report.issuesResolved)</div>
                    <div>Issues Resolved</div>
                </div>
            </div>
            
            <h2>Executive Summary</h2>
            <p>\(report.summary)</p>
        """
        
        for section in report.sections {
            html += """
            <div class="section">
                <h2>\(section.title)</h2>
                <div>\(section.content.replacingOccurrences(of: "\n", with: "<br>"))</div>
            </div>
            """
        }
        
        if let notes = report.customNotes, !notes.isEmpty {
            html += """
            <div class="section">
                <h2>Additional Notes</h2>
                <p>\(notes)</p>
            </div>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func createSampleReports() {
        guard reports.isEmpty else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        
        let sampleReport = Report(
            title: "Monthly Report - \(lastMonth.formatted(.dateTime.month().year()))",
            type: .monthly,
            summary: "During this monthly period, we monitored 5 client sites. 4 sites maintained healthy status. 1 site required attention with minor issues.",
            clientCount: 5,
            updatesPerformed: 12,
            issuesResolved: 3,
            periodStart: calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth,
            periodEnd: calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now,
            sections: [
                ReportSection(
                    title: "Updates Performed",
                    content: "Successfully updated 12 plugins and themes across all monitored sites.",
                    sectionType: .updates
                ),
                ReportSection(
                    title: "Security Analysis",
                    content: "All sites passed security scans with no critical vulnerabilities detected.",
                    sectionType: .security
                )
            ]
        )
        
        reports = [sampleReport]
        saveReports()
    }
}