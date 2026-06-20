import SwiftUI

struct ContentView: View {
    // AppKit owns popover placement, so SwiftUI reports the button click upward.
    let onSettingsButtonClicked: () -> Void

    var body: some View {
        HomeView(onSettingsButtonClicked: onSettingsButtonClicked)
            .frame(width: 180, height: 110)
    }
}

private struct HomeView: View {
    // This callback keeps HomeView simple: it does not need to know whether
    // settings appears in another popover, window, or future navigation screen.
    let onSettingsButtonClicked: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("hi")
                .font(.title)

            Button(action: onSettingsButtonClicked) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
