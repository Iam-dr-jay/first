import Foundation
import Network

/// Lightweight HTTP server that serves the NeuralFeel control console
/// to any browser on the local network (Surface Pro 6, etc.).
///
/// - GET  /          → console.html
/// - GET  /sse       → Server-Sent Events stream (live telemetry)
/// - POST /command   → JSON command body from browser
@MainActor
final class WebConsoleServer: ObservableObject {

    @Published var isRunning = false
    @Published var serverURL: String = ""

    var onCommand: (([String: Any]) -> Void)?

    private var listener: NWListener?
    private var sseConnections: [NWConnection] = []
    private let port: NWEndpoint.Port = 8080
    private var consoleHTML: String = ""

    // MARK: - Start / Stop

    func start() {
        loadHTML()
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: port)
            listener?.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.handle(conn) }
            }
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    if case .ready = state {
                        self?.isRunning = true
                        self?.serverURL = "http://\(self?.localIP() ?? "localhost"):8080"
                    }
                }
            }
            listener?.start(queue: .global(qos: .background))
        } catch {
            print("[WebConsole] listener error: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        sseConnections.forEach { $0.cancel() }
        sseConnections.removeAll()
        isRunning = false
    }

    // MARK: - Push telemetry to all SSE clients

    func push(telemetry: [String: Any]) {
        guard !sseConnections.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: telemetry),
              let jsonStr = String(data: json, encoding: .utf8) else { return }
        let event = "data: \(jsonStr)\n\n"
        let bytes = Data(event.utf8)
        sseConnections = sseConnections.filter { $0.state == .ready }
        sseConnections.forEach { $0.send(content: bytes, completion: .idempotent) }
    }

    // MARK: - Connection handling

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .background))
        receive(from: conn)
    }

    private func receive(from conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, _ in
            guard let self, let data, !data.isEmpty else { return }
            Task { @MainActor in
                self.processRequest(data: data, connection: conn)
            }
        }
    }

    private func processRequest(data: Data, connection conn: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else { return }
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        let method = parts[0], path = parts[1]

        switch (method, path) {
        case ("GET", "/"), ("GET", "/index.html"):
            serveHTML(to: conn)
        case ("GET", "/sse"):
            serveSSE(connection: conn)
        case ("POST", "/command"):
            let body = extractBody(from: request)
            if let bodyData = body.data(using: .utf8),
               let cmd = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                onCommand?(cmd)
            }
            respond(to: conn, status: "200 OK", contentType: "application/json", body: "{\"ok\":true}")
        default:
            respond(to: conn, status: "404 Not Found", contentType: "text/plain", body: "Not Found")
        }
    }

    // MARK: - Responses

    private func serveHTML(to conn: NWConnection) {
        respond(to: conn, status: "200 OK", contentType: "text/html; charset=utf-8", body: consoleHTML)
    }

    private func serveSSE(connection conn: NWConnection) {
        let header = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: text/event-stream\r\n\
        Cache-Control: no-cache\r\n\
        Connection: keep-alive\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n
        """
        conn.send(content: Data(header.utf8), completion: .idempotent)
        sseConnections.append(conn)
    }

    private func respond(to conn: NWConnection, status: String, contentType: String, body: String) {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r\n\
        Content-Type: \(contentType)\r\n\
        Content-Length: \(bodyData.count)\r\n\
        Connection: close\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n
        """
        var response = Data(header.utf8)
        response.append(bodyData)
        conn.send(content: response, completion: .contentProcessed({ _ in conn.cancel() }))
    }

    private func extractBody(from request: String) -> String {
        let separator = "\r\n\r\n"
        guard let range = request.range(of: separator) else { return "" }
        return String(request[range.upperBound...])
    }

    // MARK: - HTML loading

    private func loadHTML() {
        if let url = Bundle.module.url(forResource: "console", withExtension: "html"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            consoleHTML = content
        } else {
            consoleHTML = "<h1>NeuralFeel Console</h1><p>console.html not found in bundle.</p>"
        }
    }

    // MARK: - Local IP

    private func localIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let addr  = current.pointee.ifa_addr.pointee
            if (flags & IFF_UP) != 0, addr.sa_family == UInt8(AF_INET),
               let name = current.pointee.ifa_name, String(cString: name) == "en0" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(current.pointee.ifa_addr, socklen_t(addr.sa_len),
                               &hostname, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                }
            }
            ptr = current.pointee.ifa_next
        }
        return address
    }
}
