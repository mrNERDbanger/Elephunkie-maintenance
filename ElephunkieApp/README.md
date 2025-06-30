# Elephunkie Client Sync System

A native macOS/iOS application for monitoring and maintaining multiple WordPress client sites.

## Architecture Overview

```
┌─────────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Swift App         │     │  Local Server    │     │  Cloudflare API │
│  (SwiftUI + NIO)    │────▶│  (Port 8321)     │────▶│  DNS Management │
└─────────────────────┘     └──────────────────┘     └─────────────────┘
         │                           ▲
         │                           │
         ▼                           │
┌─────────────────────┐             │
│  Plugin Generator   │             │
│  (Per Client)       │             │
└─────────────────────┘             │
         │                           │
         ▼                           │
┌─────────────────────┐             │
│  WordPress Sites    │─────────────┘
│  (Client Plugins)   │
└─────────────────────┘
```

## Key Components Built

### 1. **Swift App Structure** ✅
- `ElephunkieApp.swift` - Main app entry point with SwiftUI
- `Package.swift` - Swift Package Manager configuration
- Support for both macOS and iOS platforms

### 2. **Local Server (SwiftNIO)** ✅
- `LocalServerManager.swift` - HTTPS server on port 8321
- Handles client heartbeats, scan results, and registrations
- Auto-detects external IP for DNS configuration

### 3. **Cloudflare Integration** ✅
- `CloudflareService.swift` - Complete API integration
- Creates/updates DNS A records (clientname.connect.elephunkie.com)
- SRV records for port mapping

### 4. **WordPress Plugin Generator** ✅
- `PluginGenerator.swift` - Generates unique plugins per client
- Each plugin includes:
  - Unique client ID and auth token
  - REST API endpoints for remote management
  - Health monitoring and reporting
  - Update capabilities

### 5. **User Interface** ✅
- `ContentView.swift` - Main navigation structure
- `DashboardView.swift` - Overview with status cards and charts
- `ClientsView.swift` - Client management interface
- `AppState.swift` - Centralized state management

### 6. **Models**
- `Client.swift` - Client data structure with health metrics
- Plugin and theme tracking
- Security issue monitoring

## Features Implemented

### Dashboard
- Client status overview (pie chart)
- Summary cards (total clients, healthy sites, updates, issues)
- Recent activity feed
- Quick action buttons

### Client Management
- Add/remove clients
- Real-time status monitoring
- Plugin generation per client
- One-click scanning
- Context menu actions

### Security
- Unique auth tokens per client
- HTTPS communication
- WordPress nonce verification
- SSL/TLS for local server

## Setup Instructions

1. **Configure Cloudflare Credentials**
   ```swift
   // Store in UserDefaults or Keychain
   UserDefaults.standard.set("your_api_token", forKey: "cloudflare_api_token")
   UserDefaults.standard.set("your_zone_id", forKey: "cloudflare_zone_id")
   ```

2. **Generate SSL Certificates**
   ```bash
   # For local development, create self-signed certificates
   openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
   ```

3. **Build and Run**
   ```bash
   # Using Swift Package Manager
   swift build
   swift run
   
   # Or open in Xcode
   open Package.swift
   ```

## WordPress Plugin Installation

1. Generate plugin for client using the app
2. Save as `elephunkie-maintenance.php`
3. Upload to client's WordPress `/wp-content/plugins/` directory
4. Activate through WordPress admin
5. Plugin auto-registers with your hub

## API Endpoints

### Local Server (Port 8321)
- `POST /api/heartbeat` - Client health check
- `POST /api/scan-results` - Receive scan data
- `POST /api/register` - New client registration
- `POST /api/events` - Event logging

### WordPress Plugin REST API
- `GET /wp-json/elephunkie/v1/status` - Get client status
- `POST /wp-json/elephunkie/v1/scan` - Trigger site scan
- `POST /wp-json/elephunkie/v1/update` - Perform updates

## Next Steps

The following components are scaffolded but need implementation:
- Updates monitoring view
- Ticket system
- Monthly report generation
- Error logging system
- Settings view

## Security Notes

- Replace self-signed certificates with proper SSL certificates in production
- Store Cloudflare credentials securely (use Keychain on macOS/iOS)
- Regularly rotate client auth tokens
- Monitor failed authentication attempts