# Teleport Architecture

## High Level Overview
Teleport is a localized P2P file transfer application. It uses **Flutter** for the cross-platform UI and **Rust** for the high-performance networking and logic, bridged by **flutter_rust_bridge (FRB)**. The system is designed to be secure, fast, and simple to use via QR code pairing.

## Tech Stack
-   **Frontend**: Flutter (Dart)
-   **Backend**: Rust
-   **Networking**: Iroh (QUIC-based, NAT traversal, encryption)
-   **Concurrency Model**: Kameo (Actor system)
-   **Communication**: flutter_rust_bridge v2 (Async Rust/Dart interoperability)

---

## Core Components

### 1. Rust Backend (`rust/src`)
The backend logic is centralized around an actor-based architecture managed by an `AppSupervisor`.

#### **Service Structure**
-   **`AppSupervisor` (`service/supervisor.rs`)**: The root actor. It spawns and manages the lifecycle of child actors and routes `UIRequest`s to the appropriate actor.
-   **`ConfigManager` (`service/config.rs`)**: Manages persistent configuration (Device Name, Target Directory, Known Peers, Keypair).
-   **`PairingActor` (`service/pairing.rs`)**: Handles the secure pairing handshake and secret verification.
-   **`TransferActor` (`service/transfer.rs`)**: Manages file transfers (sending and receiving). It tracks transfer speeds using a sliding window `SpeedTracker` and reports progress.
-   **`ConnQualityActor` (`service/conn_quality.rs`)**: Monitors connection metrics (RTT, packet loss) for active connections.
-   **`KeepAliveActor` (`service/keepalive.rs`)**: Maintains connection health ensuring NAT mappings stay open.

#### **Protocols (`protocol/`)**
Teleport defines custom protocols running over Iroh connections (QUIC streams), identified by ALPNs.
-   **Pairing (`pair.rs`)**:
    -   **ALPN**: `teleport/pair`
    -   **Purpose**: Establish trust between two devices.
    -   **Handshake**: `Helo` -> `NiceToMeetYou` / `Error`.
    -   **Security**: Uses a 6-digit code (intent) and a 128-byte secret (proximity via QR) to verify peers.
-   **Send (`send.rs`)**:
    -   **ALPN**: `teleport/send`
    -   **Purpose**: Transfer files.
    -   **Flow**: `Offer` (Name, Size) -> `Accept` / `Reject` -> `Chunk` stream -> `Done`.
    -   **Safety**: Validates peer identity before accepting. Uses temporary paths for downloads.
-   **KeepAlive (`keepalive.rs`)**:
    -   **ALPN**: `teleport/keepalive`
    -   **Purpose**: Periodic pings to maintain connectivity.

#### **API (`api/teleport.rs`)**
-   **`AppState`**: The facade exposed to Dart.
-   **`PeerInfo`**: Struct `{ addr: EndpointAddr, secret: Vec<u8> }` for connection details.
-   **`UIRequest` / `UIResponse`**: Enum-based message passing for frontend-backend communication.

### 2. Flutter Frontend (`lib/`)
#### **State Management**
-   **`TeleportScope` / `TeleportStore`**: Provides access to the global state and `AppState` (Rust) methods throughout the widget tree.
-   **Subscriptions**:
    -   `pairingSubscription`: Inbound pairing requests.
    -   `fileSubscription`: File transfer progress and status events.
    -   `connQualitySubscription`: Real-time connection stats.

#### **Features**
-   **Onboarding (`features/onboarding/`)**: Guided setup flow for new users (Device Name, Target Directory, Permissions).
-   **Settings (`features/settings/`)**: Configuration for storage location, device identity, and background permissions.
-   **Pairing (`features/pairing/`)**: QR code display/scanning and manual code entry.
-   **Send (`features/send/`)**: File selection and transfer initiation.

#### **Background Services**
-   **`BackgroundService` (`core/services/background_service.dart`)**:
    -   Uses `flutter_foreground_task` to keep the app alive on Android.
    -   Shows a persistent notification with transfer progress.
-   **`NotificationService` (`core/services/notification_service.dart`)**:
    -   Uses `flutter_local_notifications` for completion alerts.

---

## Key Workflows

### Secure Pairing Flow
1.  **Receiver**: `AppSupervisor` routes `GetSecret` to `PairingActor`. UI displays QR with `addr` and `secret`.
2.  **Initiator**: Scans QR, extracts `addr` and `secret`. User enters 6-digit code.
3.  **Initiator**: connects to `addr` via `teleport/pair`, sends `Helo { secret, code }`.
4.  **Receiver**: `PairingActor` validates `secret` matches `active_secret` and checks `code`.
5.  **Receiver**: If valid, adds Initiator to `ConfigManager` (persisted peers) and responds `NiceToMeetYou`.
6.  **Rotation**: Receiver rotates `active_secret` to prevent replay/reuse of the QR code.

### File Transfer Flow
1.  **Sender**: UI calls `send_file`. `TransferActor` initiates connection via `teleport/send`.
2.  **Sender**: Sends `Offer` (Name, Size).
3.  **Receiver**: `TransferActor` checks if sender is a known peer (via `ConfigManager`).
4.  **Receiver**: If known, checks `TargetDir`, opens file, and sends `Accept`.
5.  **Sender**: Streams file chunks. `TransferActor` calculates speed and reports `OutboundFileStatus` to UI.
6.  **Receiver**: Writes chunks. `TransferActor` calculates speed and reports `InboundFileStatus` to UI.
7.  **Completion**: Sender sends `Finish`, Receiver verifies and sends `Done`.
