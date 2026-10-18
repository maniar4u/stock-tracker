# StockTracker

<div align="center">

![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Observation-green.svg)

An iOS app for streaming simulated stock quotes over WebSocket, with local persistence and a local transport package.

[Features](#-about) • [Architecture](#️-architecture) • [Getting Started](#-getting-started) • [Testing](#-testing) • [CI](#-ci) • [Future Improvements](#-future-improvements)

</div>

---

## 📱 About

StockTracker generates a synthetic snapshot for all 25 symbols, sends it to Postman Echo, and displays the echoed JSON response. Postman echoes client-generated data; it does not supply market prices. Symbols and company blurbs ship in the bundled catalog resource; live updates merge into the UI and flush to Swift Data when appropriate. The feed starts on launch, so the list is live immediately. Browse a sortable roster, drill into detail, toggle light or dark presentation, stop or restart streaming, and recover gracefully when connectivity returns using Network reachability to resume the feed.

Default transport falls through to wss://ws.postman-echo.com/raw if Info keys are absent, which is convenient for local runs without wiring a bespoke server.

### Key Features

- Catalog-backed symbol list (bundled JSON: symbol, display name, description)
- WebSocket-driven quote stream with configurable endpoint via xcconfig into Info.plist
- Persisted snapshots and a paging API for reading stored quotes
- Connection state surfaced in the UI across idle, connecting, connected, and failure paths
- Scene-aware feed lifecycle driven by `ApplySceneActivityUseCase`
- Presentation layer with navigation and a shared palette environment
- Connectivity recovery governed by user intent in `HandleNetworkPathChangeUseCase`

---

## 🎬 Screenshots

<div align="center">

<img src="Docs/stock_listing_light.PNG" width="220" alt="Stock listing — light appearance">
<img src="Docs/stock_listing_dark.PNG" width="220" alt="Stock listing — dark appearance">
<img src="Docs/stock_detail.PNG" width="220" alt="Stock detail">
<img src="Docs/stock_no_connection.PNG" width="220" alt="No network connection">
<img src="Docs/stock_data_from_local_db.PNG" width="220" alt="Quotes sourced from local persistence">

</div>

### Demo Video
https://github.com/user-attachments/assets/8fa15f03-ac18-49b5-80eb-ce58f799a7d1



---

## 🏗️ Architecture

The `Domain/` folder is the inner layer: entities, ports (protocols) and use cases, importing only Foundation. A test enforces that. Every use case is a protocol with a single `execute` method plus a default implementation, and depends only on ports. Commands go through use cases (`StartFeed`, `StopFeed`, `RetryFeed`, `ApplySceneActivity`, `HandleNetworkPathChange`); reads go through ports (`StockRepositoryProtocol`, `FeedStatusProviding`). Outer layers implement the ports: `DefaultStockRepository` owns shared quote data and persistence, `FeedSessionCoordinator` owns the life of the current feed run, `EchoPriceFeed` adapts the socket transport, and `StockSocketKit` (a local Swift package) owns the Postman Echo transport, synthetic snapshots, handshake, retries and health checks.

SwiftUI observes `StocksListViewModel` and `StockDetailViewModel`. They call use cases for commands and read quote batches and connection status through ports, via `LiveQuoteObserver`.

| Component | Layer | Responsibility |
| --- | --- | --- |
| `Start/Stop/RetryFeedUseCase` | Domain | One user intent each. Start is idempotent and resets the quote-ordering window; Retry resets it and replaces the run; Stop always wins |
| `HandleNetworkPathChangeUseCase` | Domain | Reconnect only a running feed, only onto a usable new route; never starts a stopped or failed feed |
| `ApplySceneActivityUseCase` | Domain | Pause or resume outbound work with the app's foreground state |
| `FeedSessionControlling` / `FeedStatusProviding` / `PriceFeed` | Domain ports | Run control, read-only feed status, and one transport session |
| `FeedSessionCoordinator` | Data | Stateful: builds a session, consumes its events, retires each run exactly once, with task-identity guards |
| `EchoPriceFeed` | Data | Maps echo payloads, connection events and failures into the `PriceFeed` contract; validates batches |
| `DefaultStockRepository` | Data | Quote ordering and stale-tick rule, shared snapshots, batch publication, cache hydration |
| `QuotePersistenceScheduler` | Data | Write-behind persistence: batches writes, retries after failure, exposes the degraded flag |
| `FeedNetworkObserver` / `NetworkPathMonitor` | Infrastructure | Platform adapter: deduplicates route updates and flags the first one, then calls the use case |
| `StockSocketKit` | Package | Socket I/O, ping/pong, deadlines, close codes, retry and backoff |
| `AppDependencies` / `ApplicationBootstrap` | Composition | Assemble and inject everything once; views receive use cases and ports only |

### Layer Structure

```
┌───────────────────────────────────────────────┐
│           Presentation Layer                  │
│  SwiftUI Views + @Observable ViewModels       │
│  StocksListView, StockDetailView, Root…       │
└────────────────────┬──────────────────────────┘
                     │
┌────────────────────▼──────────────────────────┐
│           Application composition             │
│  ApplicationBootstrap, AppDependencies        │
└────────────────────┬──────────────────────────┘
                     │
┌────────────────────▼──────────────────────────┐
│  Domain (folder, Foundation only)             │
│  Entities · Ports · Use cases (execute only)  │
│  StartFeed, StopFeed, RetryFeed, …            │
└────────────────────▲──────────────────────────┘
                     │ implements ports
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────┐     ┌──────────▼─────────────────┐
│  Data Layer    │     │ Networking / Transport     │
│  DefaultStock  │     │ StockSocketKit SPM         │
│  Repository    │     │ EchoWebSocketSession,      │
│  Swift Data    │     │ Exponential backoff, TLS   │
│  Catalog JSON  │     │ StockEchoFeed protocol     │
└────────────────┘     └────────────────────────────┘
```

### Data Flow (simplified)

1. Bootstrap constructs the quote repository, one `FeedSessionCoordinator`, the default use cases over it, and a `PriceFeed` factory that wraps the socket transport with `EchoPriceFeed`. `FeedNetworkObserver` consumes events from the infrastructure network monitor.
2. View models execute the Start/Stop/Retry use cases and observe connection status through `FeedStatusProviding`. The root view executes scene and network use cases and owns the network-observation task lifetime.
3. `EchoPriceFeed` maps wire payloads and transport failures into application events. The coordinator passes quote batches to the repository, which handles ordering, publication, and persistence.
4. Each requested feed has one run holding its session and consumer. Stop invalidates that run before awaiting cleanup; stale work cannot attach to a newer run. Terminal failures require an explicit Start/Retry, and new runs await pending shutdown. Socket retries and backoff remain inside StockSocketKit.

---

## 🛠️ Tech Stack

| Area | Choices |
|------|---------|
| UI | SwiftUI, NavigationStack, Observation |
| Persistence | Swift Data with a PersistedQuote schema |
| Concurrency | async and await, actors in the socket package, MainActor repository |
| Networking | URLSessionWebSocketTask with a custom handshake coordinator |
| Structure | Domain folder in the app; StockSocketKit as the local transport package |
| Quality | SwiftLint in strict CI, XCTest per module plus an app UITest target |

Development notes:

- Swift 6.2+
- iOS 18+
- Xcode 26+

---

## 📁 Project Structure

```
StockTracker/
├── StockTracker/
│   ├── StockTrackerApp.swift
│   ├── Composition/              # Bootstrap + feed endpoint wiring
│   ├── Domain/                  # Entities/, Ports/ (protocols), UseCases/ (execute-only); Foundation only
│   ├── Config/                  # xcconfig: FEED_WEBSOCKET_* into Info.plist
│   ├── Data/
│   │   ├── Repository/           # DefaultStockRepository
│   │   ├── Feed/                 # FeedSessionCoordinator, EchoPriceFeed adapter, quote and event mapping
│   │   ├── Persistence/          # Persisted quote models + accessors
│   │   ├── Catalog/              # Catalog JSON decoding
│   │   ├── EventBroadcast/       # Broadcast fan-out
│   │   └── Formatting/           # Numeric encoding helpers
│   ├── Presentation/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Support/              # Palettes, navigation routes, localization keys
│   ├── Infrastructure/           # Network monitor and logging bridges
│   └── Resources/catalog.json
├── StockTrackerTests/
├── StockTrackerUITests/
├── StockSocketKit/               # Swift package (WebSocket transport stack)
└── Docs/                         # README screenshots
StockTracker.xcodeproj
.swiftlint.yml
.github/workflows/ci.yml
```

---

## 🚀 Getting Started

### Prerequisites

- A recent Xcode with Swift 6.2 support that matches your machine’s toolchain.
- macOS for iOS Simulator or device builds.

### Installation

1. Clone the repository and open the project folder.
2. Inspect feed wiring:
   - Values live in StockTracker/Config/Shared.xcconfig (FEED_WEBSOCKET_SCHEME, FEED_WEBSOCKET_HOST_AND_PATH), merged through Debug and Release overlays.
   - Build settings propagate them into Info.plist keys consumed by FeedTransportConfiguration.
   - If keys are empty at runtime, the app falls back to Postman Echo at wss://ws.postman-echo.com/raw.
3. Open the workspace:

   ```bash
   open StockTracker.xcodeproj
   ```

4. Select a simulator or device, then build and run.

Bootstrap failures surface through StockMessageView with copy from the string catalog.

---

## 🧪 Testing

| Suite | Scope | Command |
|-------|-------|---------|
| Domain unit tests | Model and sorting behaviors in the app target | swift test --filter DomainTests |
| Socket kit unit tests | Driver recovery, health and stale-data deadlines, lenient decoding, backpressure counters, reconnect-churn and 5,000-frame soak | swift test --package-path StockSocketKit |
| Localization guard | Every String Catalog key has English and Arabic, matching format placeholders, no key used in code is missing and no key is dead | part of the app-logic suite |
| Live smoke (opt-in) | Real Postman echo round trip of a 3-symbol snapshot | STOCKSOCKET_LIVE_TESTS=1 swift test --package-path StockSocketKit --filter LiveEchoSmokeTests |
| App logic on macOS | Same domain, repository, persistence and view-model sources/tests as the app | swift test |
| iOS unit and UI tests | App integration, navigation, feed controls, Arabic presentation | Xcode scheme StockTracker, test action |

CI runs the app-logic suite (including domain tests), the local socket package suite, and `xcodebuild test` on an iPhone simulator. The root verification package requires Swift 6.2+ and compiles the actual app logic files; it does not contain a second implementation.

The regression strategy targets observable contracts:

- A handshake deadline returns even when the socket never calls its delegate; cancellation releases checked continuations.
- Controlled socket connections exercise the real driver: handshake retries, send/read recovery, malformed data, and Stop during backoff. These tests never contact Postman.
- Gated use-case construction and startup prove duplicate Start is harmless, cancelled callers cannot launch late work, and Stop wins over suspended builders/begin calls. Explicit Retry and network changes cannot revive obsolete runs.
- Manually advanced refresh windows prove bursts publish the latest quote, cancellation prevents stale publication, and persistence batches flush on Stop. A separate integration test sends ticks through the real repository into both screen models.
- In-memory SwiftData tests verify persistence, pagination, and failure handling. Locale fixtures cover US, German, and Arabic formatting.
- Debug-only `--ui-testing` uses deterministic quotes and an isolated in-memory store. UI tests cover the feed starting on launch, Stop, sorting, detail navigation and an Arabic RTL screenshot. Release builds ignore this flag.

CI keeps `.xcresult` artifacts even on failure. Unit tests avoid external services; UI tests run serially to reduce simulator resource contention. Add minimum-OS device runs when that runtime is installed on the CI runner.

Extension tip: implement the app’s `PriceFeed` contract for a new transport. Socket-specific tests can continue using `StockEchoFeed` doubles beneath `EchoPriceFeed`.

---

## 🔄 CI

Workflow: .github/workflows/ci.yml

| Job | Purpose |
|-----|---------|
| host | Strict lint, simulator-selection helper tests, app logic including domain tests, and socket package tests |
| ios | Available iPhone simulator selection, serial Xcode unit/UI tests and diagnostic artifacts |

Workflow triggers on push and pull_request to the repository.

### Transport configuration

Transport defaults are defined once, in `EchoTransportDefaults` (StockSocketKit). The health policy, the
session and the app's `FeedTransportTuning` all read from it, so a number is changed in exactly one place.
`FeedTransportTuning` converts those defaults to milliseconds and lets a bundled
`StockTracker/Resources/FeedTransportTuning.json` (or any `Data`, such as a remote-config payload) override
any subset. Missing keys keep the default, a malformed file falls back to the defaults, and out-of-range values
are clamped, so bad config can slow the feed but not crash it.

| Key | Default | Meaning |
|-----|---------|---------|
| `outboundIntervalMilliseconds` | 1000 | Time between snapshots the client sends |
| `handshakeTimeoutMilliseconds` | 30000 | Give up on a connection attempt |
| `heartbeatIntervalMilliseconds` | 15000 | WebSocket ping cadence |
| `pongTimeoutMilliseconds` | 5000 | Ping reply deadline |
| `sendTimeoutMilliseconds` | 10000 | Send deadline |
| `staleDataTimeoutMilliseconds` | 10000 | Replace a link that delivers no decodable frame for this long |
| `maxConsecutiveDecodeFailures` | 5 | Bad frames in a row before the feed ends |
| `backoffInitialMilliseconds` / `backoffMultiplier` / `backoffMaxMilliseconds` | 250 / 1.75 / 8000 | Reconnect backoff (full jitter) |

### Batch events

One feed frame is one snapshot of all 25 symbols. The kit emits it as a single
`WebSocketPublicEvent.decodedBatch([EchoStockPayload])`, the repository publishes it as a single `QuoteBatch`
through `StockRepositoryProtocol.quoteBatches()`, and each screen refreshes once per batch. The detail screen
ignores batches that do not contain its symbol, and a batch where nothing is usable or new publishes nothing.

Breaking change from the earlier per-symbol design: `WebSocketPublicEvent.decodedTick` became `decodedBatch`
and `quoteEvents()` became `quoteBatches()`. A lone legacy payload object on the wire still decodes, as a
batch of one.

### Currency and regions

Quote currency is the instrument's currency, not the user's. These are US equities, so prices are always shown in USD, whatever the device region; only the formatting (digits, separators, symbol placement, percent style, RTL layout) follows the user's locale. Converting to a local currency would need an FX source and would silently change what a price means.

### Sorting

The sort menu has two independent choices: the field (Price, Price Change) and the direction (Low to High,
High to Low), giving four orderings. Equal values fall back to the symbol A to Z, so the order is total and rows
never swap places only because two prices tied. Symbols that have no price yet always trail A to Z.

### Persistence

Quotes are saved through `QuoteStoring`, implemented by a SwiftData `@ModelActor`, so disk reads and writes run
off the main actor. A failed write never interrupts live prices: the newest rows are kept, retried every few
seconds, and the list shows a non-blocking banner until a write succeeds.

### Test-only code

Nothing test-only ships in the app or the socket kit. Debug builds launched with `--ui-testing` swap in a
deterministic feed and an in-memory store through `AppEnvironment`, defined under `StockTracker/Testing` inside
`#if DEBUG`. Fakes for unit tests live in the test targets.

### Transport resilience and evidence

Each tick the client sends one JSON snapshot holding all 25 symbols and the echo returns it, so every
row updates together from a single frame (a lone legacy object still decodes). The real transport sends a
WebSocket ping every 15 seconds while active, with a 5-second pong deadline, a 10-second send deadline,
a 30-second handshake deadline, and a 10-second stale-data watchdog: a link that answers pings but
delivers no decodable frame is replaced. Undecodable frames are dropped and counted; five in a row end
the feed. Every timing above lives in `FeedTransportTuning` and can be overridden by the bundled
`FeedTransportTuning.json` or remote config. `EchoTLSHooks` is the seam for certificate pinning on a production backend.
Transient failures retry with full jitter from zero to an exponentially growing cap
(250 ms initially, multiplier 1.75, maximum 8 seconds). The retry counter resets after
a decoded tick, rather than merely opening a connection. Network route changes
request reconnect through the same driver; a stopped feed stays stopped.

Peer close metadata is preserved. Going-away/internal-error/service-restart/try-again
closures retry; normal closure and protocol/policy errors require an explicit user
retry. Stop sends normal closure, malformed payloads send unsupported-data, and
reserved observation-only codes are never sent. Heartbeats pause with outbound work
when the scene is inactive; foreground liveness is rechecked by the next heartbeat.

---

## 📦 Domain and Local Package

### App Domain folder

`StockTracker/Domain/` holds `Entities/` (`StockQuote`, `QuoteBatch`, sorting, connection state, feed inputs), `Ports/` (`StockRepositoryProtocol`, `PriceFeed`, `FeedSessionControlling`, `FeedStatusProviding`, `Logging`) and `UseCases/`. It imports only Foundation and has no dependency on SwiftUI, SwiftData or the transport. There is no separate domain package, so `ArchitectureTests` enforces the layer rules on the source: Domain imports only Foundation, Presentation never imports SwiftData or the socket package, and every use case exposes only `execute`.

### StockSocketKit

`StockSocketKit` is this repository’s local package, not a third-party SDK. Its `EchoWebSocketSession` generates synthetic prices and sends them through Postman Echo, with retry, timeout, and TLS policies. It builds and tests independently of the app.

`FeedSessionCoordinator` receives an injected `PriceFeed` factory and has no dependency on StockSocketKit. `ApplicationBootstrap` wraps the selected `StockEchoFeed` transport in `EchoPriceFeed`, which translates echo payloads and failures into application quotes and connection states. A future production WebSocket or gRPC adapter implements `PriceFeed` without rewriting the use cases, views, or persistence. That adapter must implement its server’s subscription, authentication, decoding, and lifecycle contract; changing only the endpoint is insufficient. No production adapter or gRPC dependency is included today.

---

## 🔮 Future Improvements

- Add certificate pinning through `EchoTLSHooks` once the app talks to its own backend.
- Document the production WebSocket JSON contract alongside the echo format so backend swaps stay predictable.
- Add explicit user-facing reconnection or status copy when the feed is paused by policy versus network loss.
- Optional widget or Live Activity for a small subset of watched symbols.
- Structured analytics or crash reporting hooks for release builds, wired behind compile flags.
- Richer charting or historical series if the backend gains time-bucketed data beyond point-in-time quotes.
- Professional review of Arabic translations and localized company descriptions. Interface strings currently support English and Arabic; bundled company descriptions remain English. USD is the quote denomination, while number and percentage presentation follows the user's locale.

---

## 📝 Code Conventions (Observed Patterns)

| Kind | Convention |
|------|-------------|
| ViewModels | ViewModel suffix, Observable and MainActor where appropriate |
| Repository | Default-prefixed types implementing domain protocols |
| Domain boundary | App Domain folder uses Foundation; the local socket package does not depend on app types |
| Diagnostics | Logging through the domain logging abstraction |

SwiftLint runs in CI; keep new work compliant before merging.

---

## 👤 Author

**Muhammad Ali Maniar**

- GitHub: [@maniarali](https://github.com/maniarali)

---

## 🙏 Acknowledgments

- [Postman Echo WebSocket sandbox](https://learning.postman.com/docs/sending-requests/websocket/create-a-websocket-request/) for default and demo connectivity at wss://ws.postman-echo.com/raw.
- Apple frameworks: SwiftUI, Swift Data, Network, URLSession.

---

<div align="center">

Swift 6 • Swift Packages • Streams and persistence

[⬆ Back to Top](#stocktracker)

</div>
