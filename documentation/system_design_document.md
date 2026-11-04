# System Design Document (SDD) — GearLease (Mobile-Centric)

## 1. High-Level Architecture Overview
The GearLease architecture supports the Flutter mobile client through a dedicated Mobile Backend-for-Frontend (BFF) gateway layer, orchestrating downstream microservices via high-speed gRPC while delivering optimized JSON/GraphQL payloads and WebSockets to mobile endpoints.

```
+-----------------------------------------------------------------------------------+
|                        Flutter Client Application Layer                           |
|       (iOS / Android / Tablet — BLoC Architecture + Hive / Isar Local Cache)      |
+-----------------------------------------+-----------------------------------------+
                                          |
                      HTTPS / TLS 1.3 Pinning + WSS WebSockets
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                  Mobile Backend-for-Frontend (BFF Gateway)                        |
|        (GraphQL / REST Aggregation, JWT / Biometric Token Auth, Rate Limits)      |
+--------------------+--------------------+--------------------+--------------------+
                     |                    |                    |
                     v                    v                    v
            +-----------------+  +-----------------+  +-----------------+
            |  Identity & KYB |  |  Underwriting   |  | Lease Servicing |
            |     Service     |  |     Engine      |  |   & Amortizer   |
            +--------+--------+  +--------+--------+  +--------+--------+
                     |                    |                    |
                     +--------------------+--------------------+
                                          |
                                          v
                              +-----------------------+
                              |   Apache Kafka Bus    |
                              +-----------+-----------+
                                          |
                     +--------------------+--------------------+
                     |                                         |
                     v                                         v
            +------------------+                      +------------------+
            |  Telemetry / IoT |                      | Push Notification|
            | Stream Processor |                      |  Service (FCM)   |
            +--------+---------+                      +--------+---------+
                     |                                         |
                     v                                         v
            +------------------+                      +------------------+
            |   TimescaleDB    |                      | APNs / FCM Gate  |
            +------------------+                      +------------------+
```

---

## 2. Flutter Mobile Application Architecture

### 2.1 State Management & Architecture Pattern
* **Pattern:** BLoC (Business Logic Component) with Clean Architecture layers:
  * **Presentation Layer:** Flutter Widgets, UI Pages, BLoC / Cubit state containers.
  * **Domain Layer:** Entities, Use Cases, Value Objects, Failure definitions (zero framework dependencies).
  * **Data Layer:** Repository implementations, Data Sources (Remote via Dio with Retrofit; Local via SQLite/Isar DB).

```
[ UI Widget / Page ] <---> [ BLoC Event / State ] <---> [ Use Case ] <---> [ Repository ]
                                                                                |
                                                      +-------------------------+-------------------------+
                                                      |                                                   |
                                            [ Remote Data Source (Dio) ]                        [ Local Cache (Isar/Hive) ]
```

### 2.2 Offline-First Synchronization Architecture
* All quote drafts, offline inspection photos, and local user notes are written directly to local encrypted storage (`Isar Database`).
* A background `SyncWorker` (using `workmanager` on Android and `BackgroundFetch` on iOS) monitors network connectivity. When connectivity returns:
  1. Local records with state `SYNC_PENDING` are pushed with idempotent UUID keys.
  2. Merge conflicts are handled through a server-authoritative timestamp approach.

### 2.3 Mobile Security Architecture
* **Biometric Auth Integration:** Fast resume with `local_auth`. The app securely stores a short-lived refresh token in hardware-backed storage (`flutter_secure_storage` utilizing iOS Keychain and Android Keystore).
* **SSL Certificate Pinning:** Enforced via `dio_http_formatter` and custom security certificates to prevent Man-in-the-Middle (MitM) inspection on cellular/public Wi-Fi networks.
* **Root/Jailbreak Detection:** Using `flutter_jailbreak_detection` to prevent app operation on compromised devices in compliance with financial regulations.

---

## 3. Real-Time Telemetry & Notification Pipeline
* **Telemetry Streaming:** Telemetry updates from connected machinery are pushed to the Flutter client via secure WebSockets (`wss://api.gearlease.com/ws/fleet`).
* **Background Notifications:** Critical notifications (overheat alerts, credit approval, signature requests) route through Firebase Cloud Messaging (FCM) and Apple Push Notification service (APNs).