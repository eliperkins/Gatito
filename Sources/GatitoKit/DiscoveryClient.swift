import Foundation
import Network

public final class DiscoveryClient {
    let browser = NWBrowser(for: .bonjour(type: "_elg._tcp.", domain: nil), using: .tcp)

    public init() {}

    public func connect(to endpoint: NWEndpoint) -> AsyncStream<URL> {
        let connection = NWConnection(to: endpoint, using: .tcp)
        return AsyncStream { continuation in
            connection.stateUpdateHandler = { state in
                #if DEBUG
                print(state)
                #endif

                if state == .ready {
                    if let endpoint = connection.currentPath?.remoteEndpoint {
                        switch endpoint {
                        case .hostPort(let host, let port):
                            var components = URLComponents()
                            components.scheme = "http"
                            switch host {
                            case .ipv4(let address):
                                #if DEBUG
                                print("ipv4 address: \(String(describing: address))")
                                #endif

                                components.host = address.debugDescription
                            case .ipv6(let address):
                                #if DEBUG
                                print("ipv6 address: \(String(describing: address))")
                                #endif

                                // see also: https://developer.apple.com/forums/thread/711196
                                components.host = "[\(address.debugDescription)]"
                            case .name(let name, let interface):
                                print("name: \(name), interface: \(String(describing: interface))")
                            default:
                                print("oh no")
                            }
                            components.port = Int(port.rawValue)
                            if let url = components.url {
                                continuation.yield(url)
                            }
                        case .url(let url):
                            #if DEBUG
                            print("url: \(url.absoluteString)")
                            #endif
                            continuation.yield(url)
                        default:
                            break
                        }
                    }
                }
            }

            continuation.onTermination = { [unowned connection] _ in
                connection.cancel()
            }

            connection.start(queue: .main)
        }
    }

    public func discoverEndpoints() -> AsyncStream<NWEndpoint> {
        AsyncStream<NWEndpoint> { continuation in
            browser.browseResultsChangedHandler = { (new, changes) in
                for result in new {
                    continuation.yield(result.endpoint)
                }
            }

            continuation.onTermination = { [unowned browser] _ in
                browser.cancel()
            }

            browser.start(queue: .main)
        }
    }
}

