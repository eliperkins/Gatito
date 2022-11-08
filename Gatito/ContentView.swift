import Combine
import GatitoKit
import SwiftUI

struct ContentView: View {
    private let discoveryClient = DiscoveryClient()

    @Environment(\.scenePhase) var scenePhase
    @State private var discoveredEndpoints = [Client: Status]()

    var body: some View {
        List(Array(discoveredEndpoints.keys), id: \.endpointURL) { client in
            if let currentStatus = discoveredEndpoints[client] {
                LightView(
                    client: client,
                    status: currentStatus
                )
            } else {
                EmptyView()
            }
        }
        .padding()
        .task {
            do {
                let urls = discoveryClient.discoverEndpoints().flatMap { endpoint in
                    discoveryClient.connect(to: endpoint)
                }

                for await url in urls {
                    let client = Client(endpointURL: url)
                    let status = try await client.fetchCurrentStatus()
                    let observedStatus = Status(
                        client: client,
                        isOn: status.isOn,
                        brightness: status.brightness,
                        temperature: status.temperature
                    )
                    discoveredEndpoints[client] = observedStatus
                    let info = try await client.fetchAccessoryInfo()
                    observedStatus.name = info.displayName.isEmpty
                        ? info.productName
                        : info.displayName

                }
            } catch {
                print(error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification).throttle(for: 5, scheduler: DispatchQueue.main, latest: false)) { _ in
            Task {
                for client in discoveredEndpoints.keys {
                    let currentStatus = try await client.fetchCurrentStatus()
                    guard let status = discoveredEndpoints[client] else { return }
                    status.updating(with: currentStatus)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
