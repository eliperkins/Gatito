import Foundation
import GatitoKit

@main
public struct Gatito {
    public static func main() async throws {
        let discoveryClient = DiscoveryClient()
        let urls = discoveryClient.discoverEndpoints().flatMap { endpoint in
            discoveryClient.connect(to: endpoint)
        }

        // TODO: use light count to determine how long to wait
        for await url in urls.prefix(1) {
            let client = Client(endpointURL: url)
            let status = try await client.fetchCurrentStatus()
            if status.isOn {
                try await client.turnOff()
                print("🌚 Turned Key Light off.")
            } else {
                try await client.turnOn()
                print("🔆 Turned Key Light on.")
            }
        }
    }
}
