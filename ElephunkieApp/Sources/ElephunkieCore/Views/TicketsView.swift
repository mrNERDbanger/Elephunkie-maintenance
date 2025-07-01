import SwiftUI

struct TicketsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var ticketManager = TicketManager()
    @State private var selectedTicket: Ticket?
    @State private var showingNewTicket = false
    @State private var filterStatus: TicketStatus = .open
    
    var filteredTickets: [Ticket] {
        switch filterStatus {
        case .all:
            return ticketManager.tickets
        default:
            return ticketManager.tickets.filter { $0.status == filterStatus }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with ticket list
            VStack(spacing: 0) {
                // Filter tabs
                Picker("Status", selection: $filterStatus) {
                    ForEach(TicketStatus.allCases, id: \.self) { status in
                        Text(status.displayName)
                            .tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tickets list
                List(selection: $selectedTicket) {
                    ForEach(filteredTickets) { ticket in
                        TicketRow(ticket: ticket)
                            .tag(ticket)
                            .contextMenu {
                                Button("Mark as \(ticket.status == .open ? "Completed" : "Open")") {
                                    ticketManager.toggleTicketStatus(ticket)
                                }
                                
                                Button("Change Priority") {
                                    // Implementation for priority change
                                }
                                
                                Divider()
                                
                                Button("Delete", role: .destructive) {
                                    ticketManager.deleteTicket(ticket)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Tickets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTicket = true
                    } label: {
                        Label("New Ticket", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let ticket = selectedTicket {
                TicketDetailView(ticket: ticket, ticketManager: ticketManager)
            } else {
                ContentUnavailableView(
                    "Select a Ticket",
                    systemImage: "ticket",
                    description: Text("Choose a ticket to view its details")
                )
            }
        }
        .sheet(isPresented: $showingNewTicket) {
            NewTicketView(ticketManager: ticketManager, clients: appState.clients)
        }
        .onAppear {
            ticketManager.loadTickets()
        }
    }
}

struct TicketRow: View {
    let ticket: Ticket
    
    var body: some View {
        HStack {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let clientName = ticket.clientName {
                    Text(clientName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(ticket.createdAt.formatted(.relative(presentation: .abbreviated)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(ticket.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                if let dueDate = ticket.dueDate {
                    Text(dueDate.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundColor(dueDate < Date() ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var priorityColor: Color {
        switch ticket.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    var statusColor: Color {
        switch ticket.status {
        case .open: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .closed: return .gray
        case .all: return .gray
        }
    }
}

struct TicketDetailView: View {
    let ticket: Ticket
    let ticketManager: TicketManager
    
    @State private var showingEditSheet = false
    @State private var newComment = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(ticket.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        if let clientName = ticket.clientName {
                            Label(clientName, systemImage: "person.circle")
                        }
                        
                        Spacer()
                        
                        Text(ticket.createdAt.formatted(.dateTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status and Priority
                HStack {
                    StatusBadge(status: ticket.status)
                    PriorityBadge(priority: ticket.priority)
                    
                    if let dueDate = ticket.dueDate {
                        DueDateBadge(dueDate: dueDate)
                    }
                    
                    Spacer()
                }
                
                // Description
                GroupBox("Description") {
                    Text(ticket.description)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Comments
                GroupBox("Comments") {
                    VStack(spacing: 12) {
                        ForEach(ticket.comments) { comment in
                            CommentView(comment: comment)
                        }
                        
                        if ticket.comments.isEmpty {
                            Text("No comments yet")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        
                        // Add comment
                        HStack {
                            TextField("Add a comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Add") {
                                addComment()
                            }
                            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Ticket Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Mark as In Progress") {
                        ticketManager.updateTicketStatus(ticket, status: .inProgress)
                    }
                    
                    Button("Mark as Completed") {
                        ticketManager.updateTicketStatus(ticket, status: .completed)
                    }
                    
                    Button("Close Ticket") {
                        ticketManager.updateTicketStatus(ticket, status: .closed)
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTicketView(ticket: ticket, ticketManager: ticketManager)
        }
    }
    
    func addComment() {
        let comment = TicketComment(
            id: UUID(),
            content: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
            author: "System",
            createdAt: Date()
        )
        
        ticketManager.addComment(to: ticket, comment: comment)
        newComment = ""
    }
}

struct StatusBadge: View {
    let status: TicketStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    var statusColor: Color {
        switch status {
        case .open: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .closed: return .gray
        case .all: return .gray
        }
    }
}

struct PriorityBadge: View {
    let priority: TicketPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(6)
    }
    
    var priorityColor: Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

struct DueDateBadge: View {
    let dueDate: Date
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
            Text(dueDate.formatted(.dateTime.month().day()))
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isOverdue ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
        .foregroundColor(isOverdue ? .red : .secondary)
        .cornerRadius(6)
    }
    
    var isOverdue: Bool {
        dueDate < Date()
    }
}

struct CommentView: View {
    let comment: TicketComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.author)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(comment.createdAt.formatted(.relative(presentation: .abbreviated)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.content)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct NewTicketView: View {
    let ticketManager: TicketManager
    let clients: [Client]
    
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedClient: Client?
    @State private var priority: TicketPriority = .medium
    @State private var dueDate: Date?
    @State private var hasDueDate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Assignment") {
                    Picker("Client", selection: $selectedClient) {
                        Text("No Client")
                            .tag(Client?.none)
                        
                        ForEach(clients) { client in
                            Text(client.name)
                                .tag(Client?.some(client))
                        }
                    }
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TicketPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName)
                                .tag(priority)
                        }
                    }
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate ?? Date().addingTimeInterval(86400) },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("New Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTicket()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    func createTicket() {
        let ticket = Ticket(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .open,
            priority: priority,
            clientID: selectedClient?.id,
            clientName: selectedClient?.name,
            createdAt: Date(),
            dueDate: hasDueDate ? dueDate : nil,
            comments: []
        )
        
        ticketManager.addTicket(ticket)
        dismiss()
    }
}

struct EditTicketView: View {
    let ticket: Ticket
    let ticketManager: TicketManager
    
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var priority: TicketPriority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    
    init(ticket: Ticket, ticketManager: TicketManager) {
        self.ticket = ticket
        self.ticketManager = ticketManager
        self._title = State(initialValue: ticket.title)
        self._description = State(initialValue: ticket.description)
        self._priority = State(initialValue: ticket.priority)
        self._dueDate = State(initialValue: ticket.dueDate)
        self._hasDueDate = State(initialValue: ticket.dueDate != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TicketPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName)
                                .tag(priority)
                        }
                    }
                    
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate ?? Date().addingTimeInterval(86400) },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Edit Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    func saveChanges() {
        ticketManager.updateTicket(
            ticket,
            title: title,
            description: description,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil
        )
        dismiss()
    }
}

struct TicketsView_Previews: PreviewProvider {
    static var previews: some View {
        TicketsView()
            .environmentObject(AppState())
    }
}