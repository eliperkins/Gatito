import GatitoKit
import SwiftUI

struct LightView: View {
    let client: Client
    @StateObject var status: Status

    private var brightnessProxy: Binding<Double> {
        .init(
            get: { Double(status.brightness) },
            set: { newValue in
                status.brightness = Int(newValue)
            }
        )
    }
    private var temperatureProxy: Binding<Double> {
        .init(
            get: { Double(status.temperature) },
            set: { newValue in
                status.temperature = Int(newValue)
            }
        )
    }

    var body: some View {
        VStack {
            Toggle(isOn: $status.isOn) {
                if let name = status.name {
                    Text(name)
                } else {
                    Text(client.endpointURL.absoluteString)
                }
            }
            .toggleStyle(.switch)
            if status.isOn {
                VStack {
                    Slider(value: brightnessProxy, in: 0...100) {
                        Text("Brightness")
                    }
                    Slider(value: temperatureProxy, in: 143...344) {
                        Text("Temperature")
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            status.isOn.toggle()
        }
    }
}
