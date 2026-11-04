# Technical Design Document (TDD) — GearLease Flutter App

## 1. Mobile Technology Stack
* **Framework:** Flutter SDK 3.24+ (Dart 3.5+) using Impeller engine.
* **State Management:** `flutter_bloc` (v8.1+) for predictable reactive state.
* **Networking:** `dio` (v5.4+) with retry interceptors, certificate pinning, and logging.
* **Local Persistence:** `isar` (v3.1+) or `sqflite_sqlcipher` for 256-bit AES-encrypted offline database.
* **Secure Storage:** `flutter_secure_storage` (KeyChain / Android Keystore).
* **Hardware & Device Plugins:**
  * Camera & Scanning: `mobile_scanner` (Camera MLKit barcode & QR scanning).
  * Biometrics: `local_auth` (Face ID / Fingerprint).
  * E-Signature: `signature` (Vector-based touch pad signature capture).
  * Document Scanning: `google_mlkit_document_scanner`.
  * Push Notifications: `firebase_messaging` + `flutter_local_notifications`.

---

## 2. Flutter BLoC State Management Model

### 2.1 Underwriting & Lease Quote BLoC Structure
```dart
// Events
abstract class QuoteEvent {}
class CalculateQuoteEvent extends QuoteEvent {
  final double requestedAmount;
  final int termMonths;
  final RepaymentStructureType repaymentType;
  CalculateQuoteEvent({
    required this.requestedAmount,
    required this.termMonths,
    required this.repaymentType,
  });
}

// States
abstract class QuoteState {}
class QuoteInitial extends QuoteState {}
class QuoteCalculating extends QuoteState {}
class QuoteCalculated extends QuoteState {
  final QuoteCalculation calculation;
  QuoteCalculated(this.calculation);
}
class QuoteError extends QuoteState {
  final String errorMessage;
  QuoteError(this.errorMessage);
}
```

---

## 3. Mobile API Specifications

### 3.1 Mobile Fast-Quote Request (POST)
* **Endpoint:** `POST /api/v1/mobile/quotes/quick-calculate`
* **Headers:** 
  * `Authorization: Bearer <jwt_access_token>`
  * `X-Device-Id: <unique_device_uuid>`
  * `Idempotency-Key: <uuid_v4>`
* **Payload:**
```json
{
  "scanned_asset_barcode": "GL-ROAST-2026-9811",
  "vendor_org_id": "550e8400-e29b-41d4-a716-446655440000",
  "invoice_amount_cents": 4500000,
  "business_ein": "12-3456789",
  "requested_term_months": 36,
  "pricing_model_requested": "REVENUE_INDEXED"
}
```
* **Response (200 OK):**
```json
{
  "quote_id": "qte_m_998822001",
  "qualification_status": "INSTANT_QUALIFIED",
  "options": [
    {
      "model": "REVENUE_INDEXED",
      "revenue_share_pct": 3.5,
      "estimated_monthly_cents": 125000,
      "floor_cents": 65000,
      "cap_cents": 185000
    },
    {
      "model": "FIXED_MONTHLY",
      "fixed_monthly_cents": 142000
    }
  ],
  "expires_in_seconds": 900
}
```

### 3.2 Offline Media Sync Contract (Upload Inspection Photos)
* **Endpoint:** `POST /api/v1/mobile/assets/inspection-bundle`
* **Content-Type:** `multipart/form-data`
* **Form Fields:**
  * `asset_id`: String (UUID)
  * `recorded_offline_at`: ISO8601 Timestamp
  * `metadata`: JSON String (GPS Lat/Lng coordinates, angle view identifiers)
  * `images`: Binary stream array (HEIC / JPEG compressed)

---

## 4. Performance & Memory Budget for Mobile
* **Image Compression Strategy:** Client-side recompression via `flutter_image_compress` to max dimension 1920x1080 at 80% quality prior to network transmission, reducing payload size by $\approx 85\%$.
* **WebSocket Heartbeat:** Pings every 30s. Automatically pauses during background app lifecycle (`AppLifecycleState.paused`) to prevent battery drain.