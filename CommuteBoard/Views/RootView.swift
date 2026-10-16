import SwiftUI

/// One tab per place: Home, Main campus, and the Business School.
struct RootView: View {
    @Environment(CommuteStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    /// Remembers the last tab. In debug builds, `-selectedTab main` picks one at launch.
    @AppStorage("selectedTab") private var selectedTab = Config.home.id

    private var selectedPlace: Place {
        Config.places.first { $0.id == selectedTab } ?? Config.home
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Config.places) { place in
                PlaceView(place: place)
                    .tabItem { Label(place.name, systemImage: place.systemImage) }
                    .tag(place.id)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh([selectedPlace]) } }
        }
        .onChange(of: store.network.isConnected) { _, connected in
            if connected { Task { await store.refreshAll() } }
        }
    }
}

#Preview {
    RootView()
        .environment(CommuteStore())
}
