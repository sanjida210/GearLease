# Mobile Application Flow (APPFLOW) — GearLease

## 1. Master Mobile Navigation Flow

```
+-----------------------------------------------------------------------------------+
|                              App Launch & Splash Screen                           |
|                       (Check Session + Biometric Prompt)                          |
+-----------------------------------------+-----------------------------------------+
                                          |
                    +---------------------+---------------------+
                    |                                           |
         [ Authenticated ]                             [ Unauthenticated ]
                    |                                           |
                    v                                           v
+---------------------------------------+   +---------------------------------------+
|          Main App Shell               |   |   Onboarding & Authentication Flow    |
| (Bottom Navigation / Responsive Rail) |   | (Phone OTP / Passkey / Business KYB)  |
+-------------------+-------------------+   +---------------------------------------+
                    |
      +-------------+-------------+-------------+
      |                           |             |
      v                           v             v
[ Fleet / Assets Tab ]    [ POS Vendor Tab ]  [ Repayments Tab ]
```

---

## 2. Detailed Mobile User Flows

### Flow 1: Vendor Showroom Floor Barcode Scan & Instant Financing
1. **Initiation:** Vendor agent opens the app on an iPad/Android tablet and selects the **"New Showroom Deal"** floating action button.
2. **Camera Scan:** The native camera viewfinder opens (`mobile_scanner`). The agent scans the machine's manufacturer barcode plate.
3. **Asset Resolution:** App fetches machine specs, MSRP, and warranty profile instantly from cache or API.
4. **Customer Pre-Qual:** Agent points camera at customer's Driver’s License to OCR basic identity, then customer inputs their Business Tax ID (EIN).
5. **Instant Underwrite:** The 90-second underwrite runs with animated progress indicators.
6. **Card Comparison & Slider:** Three interactive lease cards render. The agent hands the tablet to the customer, who adjusts term sliders.
7. **Sign on Glass:** The customer accepts terms and e-signs directly using their finger or Apple Pencil on the vector canvas.
8. **Confirmation:** Push notification and SMS copy of the executed contract sent instantly; deal is flagged as funded.

### Flow 2: Lessee Fleet Monitoring & Predictive Maintenance Alert
1. **Push Alert Received:** *"Warning: Commercial Roaster P12 running 14°C above baseline operating temperature."*
2. **Deep Link:** Tapping alert launches GearLease app straight into `AssetDetailScreen(id: 'ast_probat12')`.
3. **Diagnostics View:** Renders real-time telemetry line charts (RPM, Temperature, Running Hours) fetched via WebSocket.
4. **One-Tap Action:** Owner taps **"Schedule Covered Maintenance"**. App books an OEM certified technician and logs ticket into lease insurance record.

### Flow 3: End-of-Term "GearRelay" Guided Photo Return
1. **Alert Notification:** 60 days before lease end, lessee opens the app to decide: *Buyout*, *Upgrade*, or *Return*.
2. **Return Selected:** App triggers the **Guided Camera Return Tool**.
3. **AR Overlay Guide:** Viewfinder displays silhouette templates for 4 mandatory angles: Front, Serial Tag, Engine Housing, and Control Display.
4. **Instant CPO Valuation:** AI vision model processes photos in the cloud and provides guaranteed trade-in credit within 5 minutes.