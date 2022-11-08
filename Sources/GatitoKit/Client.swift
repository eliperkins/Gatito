import Foundation
import Network

private let decoder = JSONDecoder()

public struct Client: Equatable, Hashable {
    public let endpointURL: URL
    private let session: URLSession

    public init(endpointURL: URL) {
        self.endpointURL = endpointURL
        let config = URLSessionConfiguration.default
        config.networkServiceType = .responsiveData
        config.httpShouldUsePipelining = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        #if os(iOS)
            config.multipathServiceType = .aggregate
        #endif
        self.session = URLSession(configuration: config)
    }

    public struct CurrentStatus: Codable {
        public enum CodingKeys: String, CodingKey {
            case isOn = "on"
            case brightness
            case temperature
        }

        public var isOn: Bool
        public var brightness: Int
        public var temperature: Int

        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Client.CurrentStatus.CodingKeys> = try decoder.container(keyedBy: Client.CurrentStatus.CodingKeys.self)
            let isOn = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.isOn)
            self.isOn = isOn == 1
            self.brightness = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.brightness)
            self.temperature = try container.decode(Int.self, forKey: Client.CurrentStatus.CodingKeys.temperature)
        }
    }

    public struct AccessoryInfo: Codable {
        public enum Feature: String, Codable {
            case lights
        }

        public struct WifiInfo: Codable {
            public let ssid: String
            public let frequencyMHz: UInt
            public let rssi: Int
        }

        enum CodingKeys: String, CodingKey {
            case productName
            case hardwareBoardType
            case firmwareBuildNumber
            case firmwareVersion
            case serialNumber
            case displayName
            case features
            case wifiInfo = "wifi-info"
        }

        public let productName: String
        public let hardwareBoardType: UInt
        public let firmwareBuildNumber: UInt
        public let firmwareVersion: String
        public let serialNumber: String
        public let displayName: String
        public let features: [Feature]
        public let wifiInfo: WifiInfo
    }

    public struct Lights: Codable {
        public let numberOfLights: Int
        public let lights: [CurrentStatus]
    }

    public enum ClientError: Error {
        case missingLights
    }

    // known paths: ["elgato/lights/settings", "elgato/accessory-info", "elgato/lights"]

    public func fetchCurrentStatus() async throws -> CurrentStatus {
        let (data, _) = try await session.data(from: endpointURL.appendingPathComponent("elgato/lights"))

        let lights = try decoder.decode(Lights.self, from: data)
        guard let status = lights.lights.first else {
            throw ClientError.missingLights
        }

        return status
    }

    public func fetchAccessoryInfo() async throws -> AccessoryInfo {
        let (data, _) = try await session.data(from: endpointURL.appendingPathComponent("elgato/accessory-info"))
        return try decoder.decode(AccessoryInfo.self, from: data)
    }

    public func turnOff() async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["on": 0]]])
        _ = try await session.data(for: toggleRequest)
    }

    public func turnOn() async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["on": 1]]])
        _ = try await session.data(for: toggleRequest)
    }

    public func set(brightness: Int) async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["brightness": brightness]]])
        _ = try await session.data(for: toggleRequest)
    }

    public func set(temperature: Int) async throws {
        var toggleRequest = URLRequest(url: endpointURL.appendingPathComponent("elgato/lights"))
        toggleRequest.httpMethod = "PUT"
        toggleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["lights":[["temperature": temperature]]])
        _ = try await session.data(for: toggleRequest)
    }
}
