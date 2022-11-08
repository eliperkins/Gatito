import Combine
import GatitoKit
import SwiftUI

final class Status: ObservableObject {
    let client: Client

    @Published var name: String?
    @Published var isOn: Bool
    @Published var brightness: Int
    @Published var temperature: Int

    var cancellables = Set<AnyCancellable>()

    init(client: Client, isOn: Bool, brightness: Int, temperature: Int) {
        self.client = client
        self.isOn = isOn
        self.brightness = brightness
        self.temperature = temperature

        $isOn
            .sink(receiveValue: { newValue in
                Task {
                    if newValue {
                        try await client.turnOn()
                    } else {
                        try await client.turnOff()
                    }
                }
            })
            .store(in: &cancellables)

        $brightness
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { newValue in
                Task {
                    try await client.set(brightness: newValue)
                }
            })
            .store(in: &cancellables)

        $temperature
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { newValue in
                Task {
                    try await client.set(temperature: newValue)
                }
            })
            .store(in: &cancellables)
    }

    func updating(with status: Client.CurrentStatus) {
        isOn = status.isOn
        temperature = status.temperature
        brightness = status.brightness
    }
}
