# Product Requirement Document (PRD) — GearLease Mobile

## 1. Document Overview
* **Product Name:** GearLease Mobile
* **Platform:** Cross-Platform Mobile Application (Flutter for iOS & Android, Tablet-optimized for vendor showroom floors)
* **Track:** Enterprise / FinTech / Supply Chain
* **Status:** Active Specification (Mobile-First Architecture)
* **Target Users:** 
  1. **SMB Lessees / Business Owners:** Mobile asset supervision, instant credit applications, telematics alerts, revenue-based payment approvals.
  2. **Vendor Sales Field Agents:** Showroom/floor financing origination, QR barcode scanning of equipment serials, instant point-of-sale customer pre-qualification.

---

## 2. Executive Summary & Problem Statement
### 2.1 The Mobile Problem Space
1. **Desktop Friction on Showroom Floors:** Equipment dealers sell machinery on showroom floors, job sites, and warehouse yards where desktop CRM terminals are inaccessible.
2. **Delayed Paperwork & Document Capture:** Lessees need to upload voided checks, commercial licenses, and store photos—requiring cumbersome scanning if restricted to desktop portals.
3. **Real-Time Fleet & Machinery Visibility:** Business owners need on-the-go push alerts for telematics anomalies (e.g., motor strain, overheating) and seasonal repayment status.

### 2.2 The Mobile Solution
GearLease Mobile delivers an all-in-one Flutter client featuring:
* **Vendor Floor POS Mode:** Instant mobile credit pre-check with optical camera scan for driver's licenses, machinery barcodes, and digital e-signing on glass.
* **Instant Mobile Bank Sync:** In-app native Plaid/Open Banking flows and camera-based OCR for invoices and tax documents.
* **Real-time IoT Telemetry & Fleet Health Widget:** Push notifications for critical machinery diagnostic alerts and flexible revenue-indexed payment tracking.
* **Self-Service Remarketing ("GearRelay"):** Snap photos of end-of-term machinery directly within the app to generate automated trade-in and refurbishment quotes.

---

## 3. Goals and Objectives
* **Mobile Time-to-Offer:** Complete loan/lease pre-qualification on mobile devices in $< 90\text{ seconds}$.
* **Camera Scan Utilization:** Eliminate manual serial and license typing; $\ge 70\%$ of applications initiated with optical camera OCR.
* **Offline Resilience:** Zero data loss during on-site warehouse scans with offline-first local SQLite caching.
* **App Store Stability:** Crash-free sessions $\ge 99.8\%$ across iOS and Android ecosystems.

---

## 4. User Personas
### 4.1 SMB Lessee ("Owner Maya")
* **Device:** iPhone 15 Pro / Samsung Galaxy S24.
* **Routine:** Travels between cafes and roasting warehouses; requires push alerts when monthly payments flex based on seasonal POS revenue.
* **Key Tasks:** Biometric app unlock, viewing machine operating hours, authorizing monthly revenue-indexed deductions, and submitting maintenance requests.

### 4.2 Vendor Field Representative ("Dealer Dave")
* **Device:** iPad Air / Android Industrial Rugged Tablet.
* **Routine:** Walks industrial dealership floors with customers; needs to scan machine asset barcodes and run credit pre-qualification directly at the customer's side.
* **Key Tasks:** Scanning equipment VIN/serial plates, running instant credit estimates, presenting dynamic payment tiers, and handing tablet to customer for on-screen e-signatures.

---

## 5. Mobile Functional Requirements

### 5.1 Native Device Capabilities
* **MFR-101 (Camera OCR & Barcode Scanning):** Native camera scanning for 1D/2D barcodes (QR, Data Matrix, Code 128) on equipment plates and driver's license ID capture.
* **MFR-102 (Biometric Authentication):** Support for Face ID, Touch ID, and Android BiometricPrompt via Flutter `local_auth`.
* **MFR-103 (In-App Digital Signature on Glass):** Signature pad widget for binding e-signatures with cryptographic touch telemetry (timestamp, strokes, pressure).
* **MFR-104 (Offline-First State):** Ability to draft lease applications and capture inspection photos in remote yards without active cellular signal, syncing automatically upon network restoration.
* **MFR-105 (Push Notifications):** APNs and FCM integration for immediate underwriting approvals, payment debit notices, and predictive maintenance alerts.

### 5.2 Core Business Flows in App
* **MFR-201 (Dynamic Lease Calculator):** Interactive touch slider switching dynamically between Fixed Annuity, Revenue-Indexed, and IoT Pay-Per-Use options.
* **MFR-202 (Embedded Financial Linking):** Native Webview / Flutter SDK integration for Plaid Link and Stripe Financial Connections.
* **MFR-203 (Live Fleet Telemetry Dashboard):** Visual charts rendering engine hours, thermal profiles, and maintenance status with real-time WebSocket updates.
* **MFR-204 (GearRelay Camera Return Guide):** Guided 4-angle photo capture with AR overlays for return condition grading.

---

## 6. Non-Functional Requirements (NFRs)
* **App Launch Performance:** Cold launch $< 1.5\text{ s}$; warm launch $< 400\text{ ms}$.
* **Frame Rate:** Sustained 60/120 fps animations (Impeller rendering engine on Flutter 3.24+).
* **Security:** Secure storage via iOS Keychain and Android EncryptedSharedPreferences; SSL Pinning on all API network calls; no sensitive PII stored unencrypted in local SQLite.
* **Package Size:** Optimized app bundle $< 35\text{ MB}$ download size on both App Store and Google Play Store.