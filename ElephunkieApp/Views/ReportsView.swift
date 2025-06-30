import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var reportManager = ReportManager()
    @State private var selectedReportType: ReportType = .monthly
    @State private var selectedMonth = Date()
    @State private var showingReportGenerator = false
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Report Type Selector
                Picker("Report Type", selection: $selectedReportType) {
                    ForEach(ReportType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Month Selector for Monthly Reports
                if selectedReportType == .monthly {
                    DatePicker(
                        "Month",
                        selection: $selectedMonth,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                }
                
                // Reports List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredReports) { report in
                            ReportCard(report: report, reportManager: reportManager)
                        }
                        
                        if filteredReports.isEmpty {
                            ContentUnavailableView(
                                "No Reports",
                                systemImage: "doc.text",
                                description: Text("Generate your first report to get started")
                            )
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        generateReport()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("Generate Report", systemImage: "plus.circle")
                        }
                    }
                    .disabled(isGenerating)
                }
            }
            .sheet(isPresented: $showingReportGenerator) {
                ReportGeneratorView(
                    reportManager: reportManager,
                    clients: appState.clients,
                    reportType: selectedReportType,
                    selectedMonth: selectedMonth
                )
            }
        }
        .onAppear {
            reportManager.loadReports()
        }
    }
    
    var filteredReports: [Report] {
        let calendar = Calendar.current
        
        switch selectedReportType {
        case .monthly:
            return reportManager.reports.filter { report in
                report.type == .monthly &&
                calendar.isDate(report.createdAt, equalTo: selectedMonth, toGranularity: .month)
            }
        case .weekly:
            return reportManager.reports.filter { $0.type == .weekly }
        case .custom:
            return reportManager.reports.filter { $0.type == .custom }
        }
    }
    
    func generateReport() {
        isGenerating = true
        showingReportGenerator = true
        
        // Reset state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isGenerating = false
        }
    }
}

struct ReportCard: View {
    let report: Report
    let reportManager: ReportManager
    
    @State private var showingPreview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.headline)
                    
                    Text(report.createdAt.formatted(.dateTime.month().day().year()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ReportTypeBadge(type: report.type)
            }
            
            // Summary
            if !report.summary.isEmpty {
                Text(report.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Metrics
            HStack(spacing: 20) {
                MetricView(
                    title: "Clients",
                    value: "\(report.clientCount)",
                    icon: "person.2"
                )
                
                MetricView(
                    title: "Updates",
                    value: "\(report.updatesPerformed)",
                    icon: "arrow.triangle.2.circlepath"
                )
                
                MetricView(
                    title: "Issues",
                    value: "\(report.issuesResolved)",
                    icon: "checkmark.shield"
                )
                
                Spacer()
            }
            
            // Actions
            HStack {
                Button("Preview") {
                    showingPreview = true
                }
                .buttonStyle(.bordered)
                
                Button("Export PDF") {
                    exportPDF(report)
                }
                .buttonStyle(.bordered)
                
                Button("Export HTML") {
                    exportHTML(report)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Menu {
                    Button("Duplicate") {
                        reportManager.duplicateReport(report)
                    }
                    
                    Button("Edit") {
                        // Implementation for editing
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        reportManager.deleteReport(report)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showingPreview) {
            ReportPreviewView(report: report)
        }
    }
    
    func exportPDF(_ report: Report) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(report.title).pdf"
        savePanel.allowedContentTypes = [.pdf]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                reportManager.exportReportAsPDF(report, to: url)
            }
        }
        #endif
    }
    
    func exportHTML(_ report: Report) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(report.title).html"
        savePanel.allowedContentTypes = [.html]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                reportManager.exportReportAsHTML(report, to: url)
            }
        }
        #endif
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

struct ReportTypeBadge: View {
    let type: ReportType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(6)
    }
    
    var backgroundColor: Color {
        switch type {
        case .monthly: return .blue
        case .weekly: return .green
        case .custom: return .purple
        }
    }
}

struct ReportGeneratorView: View {
    let reportManager: ReportManager
    let clients: [Client]
    let reportType: ReportType
    let selectedMonth: Date
    
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var selectedClients: Set<UUID> = []
    @State private var includeUpdates = true
    @State private var includeSecurityIssues = true
    @State private var includePerformanceMetrics = true
    @State private var customNotes = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Report Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Custom Notes", text: $customNotes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("Clients") {
                    ForEach(clients) { client in
                        Toggle(client.name, isOn: Binding(
                            get: { selectedClients.contains(client.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedClients.insert(client.id)
                                } else {
                                    selectedClients.remove(client.id)
                                }
                            }
                        ))
                    }
                }
                
                Section("Include Sections") {
                    Toggle("Updates Performed", isOn: $includeUpdates)
                    Toggle("Security Issues", isOn: $includeSecurityIssues)
                    Toggle("Performance Metrics", isOn: $includePerformanceMetrics)
                }
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generateReport()
                    }
                    .disabled(title.isEmpty || selectedClients.isEmpty || isGenerating)
                }
            }
        }
        .onAppear {
            // Pre-fill title based on report type
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            title = "\(reportType.displayName) Report - \(formatter.string(from: selectedMonth))"
            
            // Select all clients by default
            selectedClients = Set(clients.map { $0.id })
        }
    }
    
    func generateReport() {
        isGenerating = true
        
        Task {
            let report = await reportManager.generateReport(
                title: title,
                type: reportType,
                clientIDs: Array(selectedClients),
                clients: clients,
                includeUpdates: includeUpdates,
                includeSecurityIssues: includeSecurityIssues,
                includePerformanceMetrics: includePerformanceMetrics,
                customNotes: customNotes
            )
            
            await MainActor.run {
                isGenerating = false
                dismiss()
            }
        }
    }
}

struct ReportPreviewView: View {
    let report: Report
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(report.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Date and Type
                    HStack {
                        Text("Generated: \(report.createdAt.formatted(.dateTime))")
                        Spacer()
                        ReportTypeBadge(type: report.type)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Summary
                    if !report.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Executive Summary")
                                .font(.headline)
                            
                            Text(report.summary)
                        }
                    }
                    
                    // Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Metrics")
                            .font(.headline)
                        
                        HStack(spacing: 40) {
                            MetricView(
                                title: "Clients Monitored",
                                value: "\(report.clientCount)",
                                icon: "person.2"
                            )
                            
                            MetricView(
                                title: "Updates Performed",
                                value: "\(report.updatesPerformed)",
                                icon: "arrow.triangle.2.circlepath"
                            )
                            
                            MetricView(
                                title: "Issues Resolved",
                                value: "\(report.issuesResolved)",
                                icon: "checkmark.shield"
                            )
                            
                            Spacer()
                        }
                    }
                    
                    // Content sections would be added here based on report data
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Report Preview")
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

enum ReportType: String, CaseIterable, Codable {
    case monthly = "monthly"
    case weekly = "weekly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

struct ReportsView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsView()
            .environmentObject(AppState())
    }
}