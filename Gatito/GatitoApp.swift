import SwiftUI

@main
struct GatitoApp: App {
    var body: some Scene {
        MenuBarExtra("Gatito", systemImage: "headlight.low.beam.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
