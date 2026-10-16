# CommuteBoard

A SwiftUI app with live transit and Citi Bike data for my three daily locations, one per tab:

| Tab | Shows |
|---|---|
| **Home** (110th & Malcolm X) | Downtown 2/3 at 110 St, M4 uptown, 2 Citi Bike docks |
| **Main** (Morningside campus) | M'ville shuttle to CBS, uptown/downtown 1 at 116 St, M4 both ways at Broadway & 116th, 4 docks |
| **CBS** (Manhattanville) | Downtown 1 at 125 St, M4 downtown at Broadway & Tiemann Pl, 3 docks |

Data sources:
- **Subway:** MTA GTFS-Realtime (Protocol Buffers, no key)
- **Bus:** MTA Bus Time SIRI API (free key)
- **Columbia shuttle:** TripShot, the public data behind columbia.tripshot.com (no key)
- **Bikes:** Citi Bike GBFS (no key)

## Running

1. Open `CommuteBoard.xcodeproj` in Xcode 16+ and run on an iOS 17+ simulator or device.
2. Get a free MTA Bus Time key at https://register.developer.obanyc.com, then paste it in the app under **Settings** (gear icon). The subway and Citi Bike feeds don't need a key.

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding files, run `xcodegen generate`.

## Screens

- **Tabs** (list per place): next arrival plus the two after it for each line, and live bike counts for nearby docks. Pull to refresh. The visible tab auto-refreshes every 30 s; all tabs load once at launch so each has saved data for offline use.
- **Arrivals detail**: every upcoming train or bus with minutes, clock time, and distance.
- **Dock detail**: map with both docks and the nearby stops, plus a capacity bar and e-bike/classic/open/out-of-service counts.

## Offline support

- Every successful fetch is saved to `Application Support/commute-snapshot-v2.json` and loaded at launch.
- `NWPathMonitor` detects when there's no network. The app then shows a banner and stops making requests.
- Predictions are stored as absolute times, so countdowns keep working offline and trains or buses that have already left are hidden.
- Bike counts older than 3 minutes are dimmed and marked as possibly out of date.
- Each source updates on its own, so one API failing doesn't blank the others.

To demo offline mode in the simulator: Product → Scheme → Edit Scheme → Run → Arguments → add `-simulateOffline YES` (debug builds only).

## Project layout

```
CommuteBoard/
  Config.swift              the three places (tabs) with their stops and docks
  Models/                   Arrival, BikeDock, CommuteSnapshot (Codable cache)
  Services/
    ProtobufReader.swift    minimal protobuf wire-format decoder (no dependencies)
    SubwayService.swift     GTFS-Realtime → arrivals for every subway platform in one pass
    BusTimeService.swift    SIRI StopMonitoring → M4 arrivals
    ShuttleService.swift    TripShot route summary → Columbia shuttle arrivals
    CitiBikeService.swift   GBFS station_status → dock counts
    SnapshotCache.swift     JSON persistence
    NetworkMonitor.swift    NWPathMonitor wrapper
  Store/CommuteStore.swift  parallel refresh, per-source errors, caching
  Views/                    RootView (tabs), PlaceView, ArrivalsDetail, DockDetail, Settings
```
