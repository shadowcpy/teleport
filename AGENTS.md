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
The backend logic is centralized around an actor-based `Dispatcher`.

#### **Service (`service.rs`)**
-   **`Dispatcher`**: The primary actor. It manages the application lifecycle, configuration (`ConfigManager`), and active state.
-   **State Management**:
    -   `active_secret`: A 128-byte `Vec<u8>` used for verifying pairing attempts. Rotated after every incoming pairing attempt.
    -   `peers`: List of trusted/known peers.
-   **Message Handling**:
    -   `ActionRequest`: Commands from the UI (e.g., `PairWith`, `SendFile`).
    -   `BGRequest`: Internal events from protocol handlers (e.g., `IncomingPairStarted`, `ValidateSecret`).

#### **Protocols (`protocol/`)**
Teleport defines custom protocols running over Iroh connections (QUIC streams).
-   **Pairing (`pair.rs`)**:
    -   **Purpose**: Establish trust between two devices.
    -   **Handshake**: `Helo` -> `NiceToMeetYou` / `Error`.
    -   **Security**:
        -   **Pairing Code**: A 6-digit user-visible code for intent verification.
        -   **Pairing Secret**: A 128-byte invisible secret (passed via QR) to prove physical proximity/scanning.
        -   **Validation**: The `Dispatcher` verifies the incoming secret against its `active_secret`.
    -   **Errors**: Typed errors like `WrongSecret`, `WrongPairingCode`.
-   **Send (`send.rs`)**:
    -   **Purpose**: Transfer files.
    -   **Flow**: `Offer` (Name, Size) -> `Accept` -> `Chunk` stream -> `Done`.
    -   **Safety**: Enforces `MAX_FILE_SIZE` (20 GiB) and uses secure temporary paths (`recv_{peer}_{hash}.tmp`) to prevent path traversal.

#### **API (`api/teleport.rs`)**
-   **`AppState`**: The facade exposed to Dart.
-   **`PeerInfo`**: A struct `{ addr: EndpointAddr, secret: Vec<u8> }` serialized to JSON. This is what `get_addr` returns and what `pair_with` accepts, encapsulating the complexity of the connection info.

### 2. Flutter Frontend (`lib/`)
#### **State Management**
-   The app initializes `AppState` (Rust) and subscribes to streams:
    -   `pairingSubscription()`: Listens for incoming pairing requests.
    -   `fileSubscription()`: Listens for file transfer progress.

#### **Background Services**
-   **`BackgroundService` (`background_service.dart`)**:
    -   Uses `flutter_foreground_task` to run a Foreground Service on Android.
    -   Keeps the Flutter Engine (and thus the Rust FRB backend) alive when the app is minimized.
    -   Shows a persistent notification ("Teleport is running") which updates with download progress.
-   **`NotificationService` (`notifications.dart`)**:
    -   Uses `flutter_local_notifications`.
    -   Displays a high-priority system notification when a file transfer is complete.
    -   Handles "Tap to Open" actions using `open_filex`.

#### **Key Widgets**
-   **`PairingTab` (`pairing.dart`)**:
    -   Displays the QR code.
    -   Refetches the QR code data (`getAddr`) after incoming pair events to match the rotated secret.
    -   Handles scanning and the "Enter Code" dialog.
-   **`IncomingPairingSheet`**:
    -   Prompts the user to accept/reject a pairing request and enter the 6-digit code.

---

## Key Workflows

### Secure Pairing Flow
1.  **Receiver (Rust)**: Initializes with a random `active_secret`.
2.  **Receiver (UI)**: Calls `get_addr` -> gets JSON `{ addr, secret }` -> Displays QR.
3.  **Initiator (UI)**: Scans QR -> captures JSON.
4.  **Initiator (UI)**: User enters 6-digit code displayed on Receiver.
5.  **Initiator (Rust)**: Calls `pair_with(json, code)`. extracts secret.
6.  **Handshake**: Initiator sends `Helo { secret, code }` to Receiver.
7.  **Verification**: Receiver `Dispatcher` checks:
    -   `secret == self.active_secret`?
    -   `code` matches? (checked via UI/Promise reaction).
8.  **Rotation**: Receiver generates a NEW `active_secret` immediately.
9.  **Refresh**: Receiver UI detects the event and calls `get_addr` again to show the new QR code.

### File Transfer Flow
1.  **Sender**: `send_file(peer_id, path)`.
2.  **Protocol**: Sends `Offer`.
3.  **Receiver**: Validates if `peer_id` is a known/paired peer. If so, `Accept`.
4.  **Transfer**: File sent in validated chunks. Progress reported to UI via StreamSink.
5.  **Completion**: Receiver moves file from temp dir to Downloads folder.
