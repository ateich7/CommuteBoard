import SwiftUI

@main
struct CommuteBoardApp: App {
    @State private var store = CommuteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
