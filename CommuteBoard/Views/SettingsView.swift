import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Config.busTimeKeyDefaultsKey) private var busTimeKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste your key", text: $busTimeKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    Link(destination: URL(string: "https://register.developer.obanyc.com")!) {
                        Label("Get a free key", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("MTA Bus Time API key")
                } footer: {
                    Text("Needed for M4 arrivals. The subway and Citi Bike feeds don't need a key.")
                }

                Section("Data sources") {
                    LabeledContent("Subway", value: "MTA GTFS-Realtime")
                    LabeledContent("Bus", value: "MTA Bus Time (SIRI)")
                    LabeledContent("Bikes", value: "Citi Bike GBFS")
                }

                Section {
                    Text("Data refreshes every 30 seconds and is saved on the device. With no connection, the app shows the saved data and keeps counting down to the predicted arrival times.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Offline mode")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
