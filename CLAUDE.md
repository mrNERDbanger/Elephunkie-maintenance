# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elephunkie Maintenance System - A WordPress site maintenance and monitoring solution consisting of:
- WordPress plugin (PHP) for client sites to report health metrics
- React Native app (JavaScript) for iOS/macOS as a central management hub

## Common Commands

### Development
Since this project lacks standard package management files, development setup requires:

**For WordPress Plugin:**
- Copy `wp-maintenance-plugin.php` to WordPress plugin directory: `wp-content/plugins/elephunkie-maintenance/`
- Activate through WordPress admin panel
- No build process required (standard PHP)

**For React Native App:**
- First initialize React Native project: `npx react-native init ElephunkieApp`
- Copy `wp-maintenance-native-app.js` into the project
- Install dependencies: `npm install`
- Run on iOS: `npx react-native run-ios`
- Run on macOS: `npx react-native run-macos`

### Testing
No test framework is currently configured. To add tests:
- For PHP: Consider PHPUnit for WordPress plugin testing
- For React Native: Jest comes pre-configured with React Native

## Architecture

### Communication Flow
1. WordPress sites run the client plugin (`wp-maintenance-plugin.php`)
2. Plugin sends health data to central hub at https://elephunkie.com
3. React Native app acts as management dashboard
4. App can generate new client plugins with unique credentials

### Key Components

**WordPress Plugin (`wp-maintenance-plugin.php`)**
- Monitors: plugin updates, security events, errors, login attempts
- REST API endpoint: `/wp-json/elephunkie-maintenance/v1/receive-scan`
- Admin page: `admin.php?page=elephunkie-maintenance`
- Daily health check cron job

**React Native App (`wp-maintenance-native-app.js`)**
- Client management dashboard
- Site scanning capabilities
- WordPress plugin generator
- Cloudflare DNS integration
- Local server functionality (port 8321)

### Security Considerations
- Plugin uses WordPress nonces for API security
- Unique client IDs and auth tokens per installation
- Never commit credentials.txt or API keys
- All hub communication should use HTTPS

## Development Notes

### Missing Infrastructure
The following components referenced in code are not included:
- Backend API server implementation
- Cloudflare API integration details
- Database schema for storing client data
- Plugin distribution mechanism

### Future Implementation Requirements
Based on README.txt specifications:
- Swift-based native app (current is React Native)
- SwiftNIO-based local server
- Dynamic DNS updates via Cloudflare
- Two-way secure communication protocol
- Monthly report generation system