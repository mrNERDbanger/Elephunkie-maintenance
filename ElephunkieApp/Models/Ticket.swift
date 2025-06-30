import Foundation

struct Ticket: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var status: TicketStatus
    var priority: TicketPriority
    var clientID: UUID?
    var clientName: String?
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var comments: [TicketComment]
    
    init(id: UUID, title: String, description: String, status: TicketStatus, priority: TicketPriority, clientID: UUID? = nil, clientName: String? = nil, createdAt: Date, dueDate: Date? = nil, comments: [TicketComment] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.clientID = clientID
        self.clientName = clientName
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.dueDate = dueDate
        self.comments = comments
    }
}

enum TicketStatus: String, Codable, CaseIterable {
    case all = "all"
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .closed: return "Closed"
        }
    }
}

enum TicketPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

struct TicketComment: Identifiable, Codable {
    let id: UUID
    var content: String
    var author: String
    var createdAt: Date
}

@MainActor
class TicketManager: ObservableObject {
    @Published var tickets: [Ticket] = []
    
    private let storageURL = AppConfig.documentsDirectory.appendingPathComponent("tickets.json")
    
    init() {
        loadTickets()
        createSampleTickets()
    }
    
    func loadTickets() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            tickets = try JSONDecoder().decode([Ticket].self, from: data)
        } catch {
            print("Failed to load tickets: \(error)")
        }
    }
    
    func saveTickets() {
        do {
            let data = try JSONEncoder().encode(tickets)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save tickets: \(error)")
        }
    }
    
    func addTicket(_ ticket: Ticket) {
        tickets.append(ticket)
        saveTickets()
    }
    
    func updateTicket(_ ticket: Ticket, title: String? = nil, description: String? = nil, priority: TicketPriority? = nil, dueDate: Date? = nil) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        
        if let title = title { tickets[index].title = title }
        if let description = description { tickets[index].description = description }
        if let priority = priority { tickets[index].priority = priority }
        tickets[index].dueDate = dueDate
        tickets[index].updatedAt = Date()
        
        saveTickets()
    }
    
    func updateTicketStatus(_ ticket: Ticket, status: TicketStatus) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        
        tickets[index].status = status
        tickets[index].updatedAt = Date()
        
        saveTickets()
    }
    
    func toggleTicketStatus(_ ticket: Ticket) {
        let newStatus: TicketStatus = ticket.status == .open ? .completed : .open
        updateTicketStatus(ticket, status: newStatus)
    }
    
    func deleteTicket(_ ticket: Ticket) {
        tickets.removeAll { $0.id == ticket.id }
        saveTickets()
    }
    
    func addComment(to ticket: Ticket, comment: TicketComment) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        
        tickets[index].comments.append(comment)
        tickets[index].updatedAt = Date()
        
        saveTickets()
    }
    
    // Auto-create tickets from critical errors
    func createTicketFromError(clientID: UUID, clientName: String, error: String) {
        let ticket = Ticket(
            id: UUID(),
            title: "Critical Error: \(clientName)",
            description: "Automatic ticket created from critical error:\n\n\(error)",
            status: .open,
            priority: .critical,
            clientID: clientID,
            clientName: clientName,
            createdAt: Date()
        )
        
        addTicket(ticket)
    }
    
    // Create ticket from detailed error report
    func createTicketFromDetailedError(clientID: UUID, clientName: String, errorData: [String: Any]) {
        let errorType = errorData["error_type"] as? String ?? "Unknown Error"
        let message = errorData["message"] as? String ?? "No details available"
        let file = errorData["file"] as? String ?? ""
        let line = errorData["line"] as? Int ?? 0
        let stackTrace = errorData["stack_trace"] as? String ?? ""
        
        var description = "**Automatic ticket created from critical error**\n\n"
        description += "**Error Type:** \(errorType)\n"
        description += "**Message:** \(message)\n"
        
        if !file.isEmpty {
            description += "**File:** \(file)"
            if line > 0 {
                description += " (Line \(line))"
            }
            description += "\n"
        }
        
        if !stackTrace.isEmpty {
            description += "\n**Stack Trace:**\n```\n\(stackTrace)\n```\n"
        }
        
        let ticket = Ticket(
            id: UUID(),
            title: "Critical Error: \(errorType) on \(clientName)",
            description: description,
            status: .open,
            priority: .critical,
            clientID: clientID,
            clientName: clientName,
            createdAt: Date(),
            comments: [
                TicketComment(
                    id: UUID(),
                    content: "This ticket was automatically generated from a critical error. Please investigate immediately.",
                    author: "System",
                    createdAt: Date()
                )
            ]
        )
        
        addTicket(ticket)
    }
    
    // Create ticket from recurring issues
    func createTicketFromRecurringIssue(clientID: UUID, clientName: String, issueType: String, occurrences: Int) {
        let ticket = Ticket(
            id: UUID(),
            title: "Recurring Issue: \(issueType) on \(clientName)",
            description: "**Automatic ticket created from recurring issue**\n\n**Issue Type:** \(issueType)\n**Occurrences:** \(occurrences) times in the last 24 hours\n\nThis issue has occurred multiple times and requires attention to prevent further problems.",
            status: .open,
            priority: .high,
            clientID: clientID,
            clientName: clientName,
            createdAt: Date()
        )
        
        addTicket(ticket)
    }
    
    // Create sample tickets for demo
    private func createSampleTickets() {
        guard tickets.isEmpty else { return }
        
        let sampleTickets = [
            Ticket(
                id: UUID(),
                title: "Update WordPress core for Client A",
                description: "WordPress 6.3 is available with security fixes. Need to update and test all functionality.",
                status: .open,
                priority: .high,
                clientName: "Client A",
                createdAt: Date().addingTimeInterval(-86400),
                dueDate: Date().addingTimeInterval(86400 * 2),
                comments: [
                    TicketComment(
                        id: UUID(),
                        content: "Scheduled for this weekend during maintenance window.",
                        author: "System",
                        createdAt: Date().addingTimeInterval(-3600)
                    )
                ]
            ),
            Ticket(
                id: UUID(),
                title: "Security scan failed for Client B",
                description: "Automated security scan detected potential vulnerabilities. Manual review required.",
                status: .inProgress,
                priority: .critical,
                clientName: "Client B",
                createdAt: Date().addingTimeInterval(-7200)
            ),
            Ticket(
                id: UUID(),
                title: "Plugin compatibility check",
                description: "Several plugins need compatibility verification after WordPress update.",
                status: .open,
                priority: .medium,
                clientName: "Client C",
                createdAt: Date().addingTimeInterval(-172800)
            ),
            Ticket(
                id: UUID(),
                title: "Backup verification completed",
                description: "Weekly backup verification process completed successfully.",
                status: .completed,
                priority: .low,
                clientName: "Client A",
                createdAt: Date().addingTimeInterval(-259200)
            )
        ]
        
        tickets = sampleTickets
        saveTickets()
    }
}