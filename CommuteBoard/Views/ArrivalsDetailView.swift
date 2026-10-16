import SwiftUI
import MapKit

/// Every upcoming arrival for one train platform, bus stop, or shuttle stop.
struct ArrivalsDetailView: View {
    @Environment(CommuteStore.self) private var store

    let board: Board
    let place: Place

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let fetchedAt = store.snapshot.fetchedAt(for: board)
            let upcoming = store.snapshot.arrivals(for: board).upcoming(now: context.date, fetchedAt: fetchedAt)
            List {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: board.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                    ))) {
                        Marker(board.title, systemImage: board.kind.systemImage, coordinate: board.coordinate)
                            .tint(board.kind == .subway ? Color.subwayRed : board.kind == .bus ? Color.busBlue : Color.columbiaNavy)
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())

                    Text(board.stopName)
                        .font(.headline)
                    Link(destination: DockDetailView.walkingDirectionsURL(to: board.coordinate)) {
                        Label("Walking directions", systemImage: "figure.walk")
                    }
                }

                Section {
                    if upcoming.isEmpty {
                        Text(store.isOffline ? "Saved times have passed" : PlaceView.emptyText(for: board))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(upcoming) { arrival in
                        ArrivalRow(arrival: arrival, now: context.date)
                    }
                } header: {
                    Text("Upcoming")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        UpdatedFooter(fetchedAt: fetchedAt, error: store.errors[board.id], isOffline: store.isOffline, now: context.date)
                        if board.kind == .shuttle {
                            Text("Shuttle times come from Columbia's TripShot tracker. \"Scheduled\" means the shuttle isn't reporting live GPS yet.")
                        }
                        if store.isOffline {
                            Text("Offline: counting down from the last predictions. Arrivals that have already passed are hidden.")
                        }
                    }
                }
            }
        }
        .navigationTitle(board.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh([place]) }
    }
}
