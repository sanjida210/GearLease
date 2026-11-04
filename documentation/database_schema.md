# Database Schema Specification — GearLease (Mobile & Core)

## 1. Mobile-Specific Sync & Core ERD Architecture

```
+-------------------+           +-----------------------+           +----------------------+
|   organizations   |<---+      |  lease_applications   |<--------->| mobile_client_tokens |
+-------------------+    |      +-----------------------+           +----------------------+
| id (PK)           |    |      | id (PK)               |           | id (PK)              |
| legal_name        |    |      | device_uuid           |           | user_id (FK)         |
| tax_id_encrypted  |    +----->| vendor_agent_id (FK)  |           | fcm_push_token       |
| org_type          |           | offline_created_at    |           | device_os (IOS/ANDR) |
+-------------------+           | status                |           | last_active_at       |
                                +-----------+-----------+           +----------------------+
                                            |
                                            v
+-------------------+           +-----------------------+           +----------------------+
|  hardware_assets  |<--------->|   lease_contracts     |<--------->|  mobile_sign_events  |
+-------------------+           +-----------------------+           +----------------------+
| id (PK)           |           | id (PK)               |           | id (PK)              |
| barcode_symbology |           | pricing_model         |           | contract_id (FK)     |
| qr_code_content   |           | monthly_base_cents    |           | biometric_auth_type  |
| serial_number     |           | status                |           | signature_svg_blob   |
| iot_device_id     |           +-----------------------+           | signed_ip_and_gps    |
+-------------------+                                               +----------------------+
```

---

## 2. PostgreSQL DDL Extensions for Mobile Operations

```sql
-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Mobile Push Notification Registry
CREATE TABLE mobile_client_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    device_uuid VARCHAR(128) NOT NULL UNIQUE,
    platform_os VARCHAR(16) NOT NULL CHECK (platform_os IN ('IOS', 'ANDROID', 'IPADOS')),
    app_version VARCHAR(32) NOT NULL,
    fcm_push_token TEXT NOT NULL,
    is_biometrics_enabled BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hardware Assets with Barcode Indices
CREATE TABLE hardware_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL,
    serial_number VARCHAR(128) UNIQUE NOT NULL,
    barcode_payload VARCHAR(255) UNIQUE,
    barcode_symbology VARCHAR(32) DEFAULT 'CODE_128',
    make VARCHAR(128) NOT NULL,
    model VARCHAR(128) NOT NULL,
    category VARCHAR(64) NOT NULL,
    initial_value_cents BIGINT NOT NULL,
    iot_device_identifier VARCHAR(128) UNIQUE,
    current_condition_rating VARCHAR(16) DEFAULT 'GRADE_A',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mobile E-Signature Audit Trail
CREATE TABLE mobile_sign_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL,
    signer_user_id UUID NOT NULL,
    biometric_used VARCHAR(32), -- 'FACE_ID', 'TOUCH_ID', 'ANDROID_BIOMETRIC'
    signature_vector_path TEXT NOT NULL, -- Stored vector data of hand stroke
    signer_ip VARCHAR(64) NOT NULL,
    gps_latitude NUMERIC(9, 6),
    gps_longitude NUMERIC(9, 6),
    signed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Offline Sync Queue Log (For conflict resolution tracking)
CREATE TABLE mobile_offline_sync_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_uuid VARCHAR(128) NOT NULL,
    idempotency_key UUID NOT NULL UNIQUE,
    action_type VARCHAR(64) NOT NULL,
    client_timestamp TIMESTAMPTZ NOT NULL,
    server_synced_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(32) DEFAULT 'COMMITTED'
);

CREATE INDEX idx_assets_barcode ON hardware_assets(barcode_payload);
CREATE INDEX idx_mobile_tokens_user ON mobile_client_tokens(user_id);
CREATE INDEX idx_sync_idempotency ON mobile_offline_sync_log(idempotency_key);
```