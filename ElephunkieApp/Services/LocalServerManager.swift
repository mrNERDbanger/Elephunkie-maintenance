import Foundation
import NIO
import NIOHTTP1
import NIOSSL

enum ServerError: Error {
    case certificatesNotFound
    case bindFailed
    case sslContextCreationFailed
}

@MainActor
class LocalServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var serverAddress: String = ""
    @Published var externalIP: String = ""
    
    private var group: EventLoopGroup?
    private var channel: Channel?
    private let port = 8321
    
    func startServer() async {
        guard !isRunning else { return }
        
        await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
                    
                    let sslContext = try self.createSSLContext()
                    
                    let bootstrap = ServerBootstrap(group: self.group!)
                        .serverChannelOption(ChannelOptions.backlog, value: 256)
                        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                        .childChannelInitializer { channel in
                            channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext)).flatMap {
                                channel.pipeline.configureHTTPServerPipeline()
                            }.flatMap {
                                channel.pipeline.addHandler(HTTPHandler())
                            }
                        }
                        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                        .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                    
                    self.channel = try bootstrap.bind(host: "0.0.0.0", port: self.port).wait()
                    
                    await MainActor.run {
                        self.isRunning = true
                        self.serverAddress = "https://localhost:\(self.port)"
                    }
                    
                    // Get external IP
                    if let ip = await self.getExternalIP() {
                        await MainActor.run {
                            self.externalIP = ip
                        }
                    }
                    
                    print("Server running on port \(self.port)")
                    continuation.resume()
                    
                } catch {
                    print("Failed to start server: \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    func stopServer() async {
        guard isRunning else { return }
        
        try? await channel?.close()
        try? await group?.shutdownGracefully()
        
        isRunning = false
        serverAddress = ""
    }
    
    private func createSSLContext() throws -> NIOSSLContext {
        // Use the generated SSL certificates
        let bundle = Bundle.main
        guard let certPath = bundle.path(forResource: "server", ofType: "crt"),
              let keyPath = bundle.path(forResource: "server", ofType: "key") else {
            
            // Fallback: try to use certificates from Resources directory
            let resourcesPath = FileManager.default.currentDirectoryPath + "/ElephunkieApp/Resources/Certificates"
            let certFile = resourcesPath + "/server.crt"
            let keyFile = resourcesPath + "/server.key"
            
            if FileManager.default.fileExists(atPath: certFile) && 
               FileManager.default.fileExists(atPath: keyFile) {
                let configuration = TLSConfiguration.makeServerConfiguration(
                    certificateChain: [.file(certFile)],
                    privateKey: .file(keyFile)
                )
                return try NIOSSLContext(configuration: configuration)
            }
            
            throw ServerError.certificatesNotFound
        }
        
        let configuration = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.file(certPath)],
            privateKey: .file(keyPath)
        )
        return try NIOSSLContext(configuration: configuration)
    }
    
    private func getExternalIP() async -> String? {
        // Query external IP service
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to get external IP: \(error)")
            return nil
        }
    }
}

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var buffer = ByteBufferAllocator().buffer(capacity: 0)
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            handleRequest(context: context, request: request)
        case .body(let bodyData):
            buffer.writeBuffer(&bodyData)
        case .end:
            handleRequestEnd(context: context)
        }
    }
    
    private func handleRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // Route handling
        switch request.uri {
        case "/api/heartbeat":
            handleHeartbeat(context: context, request: request)
        case "/api/scan-results":
            handleScanResults(context: context, request: request)
        case "/api/register":
            handleClientRegistration(context: context, request: request)
        default:
            sendResponse(context: context, status: .notFound, body: "Not Found")
        }
    }
    
    private func handleHeartbeat(context: ChannelHandlerContext, request: HTTPRequestHead) {
        let response = ["status": "ok", "timestamp": ISO8601DateFormatter().string(from: Date())]
        sendJSONResponse(context: context, response: response)
    }
    
    private func handleScanResults(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // Handle scan results from WordPress plugin
        sendResponse(context: context, status: .ok, body: "Scan results received")
    }
    
    private func handleClientRegistration(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // Handle new client registration
        sendResponse(context: context, status: .ok, body: "Client registered")
    }
    
    private func handleRequestEnd(context: ChannelHandlerContext) {
        buffer.clear()
    }
    
    private func sendResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, body: String) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(body.count)")
        
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: body.count)
        buffer.writeString(body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    private func sendJSONResponse(context: ChannelHandlerContext, response: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(data.count)")
            
            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            
            var buffer = context.channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        } catch {
            sendResponse(context: context, status: .internalServerError, body: "JSON encoding error")
        }
    }
}