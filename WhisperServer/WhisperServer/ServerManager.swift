import Foundation
import Darwin
import WhisperKit
import Swifter

@MainActor
final class ServerManager: ObservableObject {
    enum ModelOption: String, CaseIterable, Identifiable {
        case tiny
        case base
        case small
        case largeV3Turbo = "large-v3-turbo"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .tiny: return "Tiny"
            case .base: return "Base"
            case .small: return "Small"
            case .largeV3Turbo: return "Large v3 Turbo"
            }
        }
    }

    @Published var isServerRunning = false
    @Published var serverPort: Int = 8080
    @Published var lastTranscript = ""
    @Published var modelOption: ModelOption = .largeV3Turbo
    @Published var statusMessage = "Stopped"
    @Published var isLoadingModel = false
    @Published var localIPAddress = "unknown"

    private var whisperKit: WhisperKit?
    private let server = HttpServer()

    func prepareModel() async {
        isLoadingModel = true
        await updateStatus("Loading model...")

        do {
            whisperKit = try await makeWhisperKit()
            localIPAddress = Self.currentIPv4Address() ?? "unknown"
            await updateStatus("Model ready")
        } catch {
            await updateStatus("Model load failed: \(error.localizedDescription)")
            whisperKit = nil
        }

        isLoadingModel = false
    }

    private func makeWhisperKit() async throws -> WhisperKit {
        if modelOption == .largeV3Turbo {
            do {
                return try await WhisperKit()
            } catch {
                return try await WhisperKit(WhisperKitConfig(model: modelOption.rawValue))
            }
        }

        return try await WhisperKit(WhisperKitConfig(model: modelOption.rawValue))
    }

    func startServer() async {
        guard !isServerRunning else { return }

        server.POST["/transcribe"] = { [weak self] request in
            guard let self = self else {
                return .internalServerError
            }
            return await self.handleTranscribe(request: request)
        }

        do {
            try server.start(UInt16(serverPort), forceIPv4: true)
            isServerRunning = true
            localIPAddress = Self.currentIPv4Address() ?? "unknown"
            await updateStatus("Server running")
        } catch {
            await updateStatus("Server failed: \(error.localizedDescription)")
            isServerRunning = false
        }
    }

    func stopServer() {
        if server.running {
            server.stop()
        }
        isServerRunning = false
        Task {
            await updateStatus("Server stopped")
        }
    }

    private func handleTranscribe(request: HttpRequest) async -> HttpResponse {
        guard request.method == "POST" else {
            return .badRequest(nil)
        }

        let audioData = Data(request.body)
        if audioData.isEmpty {
            return .badRequest(.text("Missing audio payload"))
        }

        do {
            let transcript = try await transcribeAudio(data: audioData)
            lastTranscript = transcript
            let responseObject = ["text": transcript]
            let body = try JSONEncoder().encode(responseObject)
            return .raw(200, "OK", ["Content-Type": "application/json"], body)
        } catch {
            let errorMessage = "Transcription error: \(error.localizedDescription)"
            await updateStatus(errorMessage)
            return .internalServerError(.text(errorMessage))
        }
    }

    private func transcribeAudio(data: Data) async throws -> String {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_input_\(UUID().uuidString).wav")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard let whisperKit = whisperKit else {
            throw NSError(domain: "WhisperServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let transcription = try await whisperKit.transcribe(audioPath: tempURL.path)
        let text = transcription?.text ?? ""
        return text
    }

    private func updateStatus(_ message: String) async {
        statusMessage = message
    }

    private static func currentIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            let isIPv4 = addr.sa_family == sa_family_t(AF_INET)
            let isUp = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isIPv4 && isUp && !isLoopback {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                    break
                }
            }
        }

        return address
    }
}
