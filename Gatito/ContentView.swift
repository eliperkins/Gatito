import Network
import SwiftUI

struct Client {
    static func discoverEndpoints() async -> [URL] {
        let browser = NWBrowser(for: .bonjour(type: "_elg._tcp.", domain: nil), using: .tcp)
        return await withCheckedContinuation { continuation in
            browser.browseResultsChangedHandler = { (new, changes) in
                for x in new {
                    let connection = NWConnection(to: x.endpoint, using: .tcp)
                    connection.stateUpdateHandler = { state in
                        print(state)
                        if state == .ready {
                            if let endpoint = connection.currentPath?.remoteEndpoint {
                                switch endpoint {
                                case .hostPort(let host, let port):
                                    var components = URLComponents()
                                    components.scheme = "http"
                                    switch host {
                                    case .ipv4(let address):
                                        components.host = address.debugDescription
                                    case .ipv6(let address):
                                        components.host = address.debugDescription
                                    case .name(let name, let interface):
                                        print("name: \(name), interface: \(String(describing: interface))")
                                    default:
                                        print("oh no")
                                    }
                                    components.port = Int(port.rawValue)
//                                    connection.cancel()
                                    continuation.resume(returning: [components.url].compactMap { $0 })
                                case .url(let url):
//                                    connection.cancel()
                                    continuation.resume(returning: [url])
                                default:
                                    break
                                }
                            }
                        }
                    }
                    connection.start(queue: .main)
                }
            }
            browser.start(queue: .main)
        }
    }

    let endpointURL: URL
    private let session: URLSession = .shared
    private let decoder = JSONDecoder()

    struct CurrentStatus: Codable {
        enum CodingKeys: String, CodingKey {
            case isOn = "on"
            case brightness
            case temperature
        }

        let isOn: Bool
        let brightness: Int
        let temperature: Int

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Client.CurrentStatus.CodingKeys> = try decoder.container(keyedBy: Client.CurrentStatus.CodingKeys.self)
            let isOn = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.isOn)
            self.isOn = isOn == 1
            self.brightness = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.brightness)
            self.temperature = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.temperature)
        }
    }

    struct Lights: Codable {
        let numberOfLights: Int
        let lights: [CurrentStatus]
    }

    enum ClientError: Error {
        case missingLights
    }

    // known paths: ["elgato/lights/settings", "elgato/accessory-info", "elgato/lights"]

    func fetchCurrentStatus() async throws -> CurrentStatus {
        let (data, _) = try await session.data(from: endpointURL.appendingPathComponent("elgato/lights"))

        let lights = try decoder.decode(Lights.self, from: data)
        guard let status = lights.lights.first else {
            throw ClientError.missingLights
        }

        return status
    }

    func turnOff() async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["on": 0]]])
        _ = try await URLSession.shared.data(for: toggleRequest)
    }

    func turnOn() async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["on": 1]]])
        _ = try await URLSession.shared.data(for: toggleRequest)
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
        .task {
            do {
                let urls = await Client.discoverEndpoints()
                if let url = urls.first {
                    let client = Client(endpointURL: url)
                    let status = try await client.fetchCurrentStatus()
                    if status.isOn {
                        try await client.turnOff()
                    } else {
                        try await client.turnOn()
                    }
                }
            } catch {
                print(error)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
