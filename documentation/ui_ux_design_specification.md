# Mobile UI/UX Design Specification (UIspec) — GearLease

## 1. Design Language & Flutter Component System
* **Design Philosophy:** Utilitarian Industrial FinTech. Crisp contrast, tactile haptic feedback, dark mode primary, high glanceability in bright showroom/warehouse environments.
* **Palette:**
  * **Surface / Scaffold Dark:** `#090D14`
  * **Card & Modal Surface:** `#121927`
  * **Brand Precision Cyan:** `#0D9488` / `#14B8A6` (Primary interactive)
  * **Industrial Amber:** `#F59E0B` (Alerts, usage meter milestones)
  * **Performance Green:** `#10B981` (Approved states, low risk)
  * **Critical Red:** `#EF4444` (Telemetry faults, late payments)
* **Typography:** `GoogleFonts.spaceGrotesk()` for headline metrics and rates; `GoogleFonts.inter()` for body and tabular ledger data.

---

## 2. Key Mobile Screen Wireframes

### 2.1 Screen A: Vendor Floor Scanner & Instant Quote View
```
+--------------------------------------------------+
|  [<]  Equipment Scanner               [Flash: On]|
|                                                  |
|          +----------------------------+          |
|          |    [  SCAN BARCODE/QR  ]   |          |
|          |                            |          |
|          |    |||||| |||| ||||| |||   |          |
|          |                            |          |
|          +----------------------------+          |
|          Align camera over machine serial tag    |
|                                                  |
|  [v] Detected: Probat P12 III Roaster            |
|      MSRP: $45,000.00 | Cat: Commercial Kitchen  |
+--------------------------------------------------+
|  Select Repayment Structure                      |
|                                                  |
|  [ FIXED TERM ]      [ REVENUE-INDEXED ]  (ACTIVE)|
|  $1,420 / mo         3.5% of monthly gross sales |
|                      Floor: $650 | Cap: $1,850   |
|                                                  |
|  Term: [ < 36 Months > ]   Down: $0.00           |
|                                                  |
|  [====== Hand Tablet To Customer to Sign ======] |
+--------------------------------------------------+
```

### 2.2 Screen B: SMB Lessee Fleet Telemetry Dashboard
```
+--------------------------------------------------+
|  GearLease Mobile                [Bell: 1] [Maya]|
|  ACTIVE FLEET (3 Assets)                         |
+--------------------------------------------------+
|  TOTAL CAPITAL COMMITTED        NEXT ACH DEDUCTION|
|  $118,500                       Nov 15 ($2,290)   |
+--------------------------------------------------+
|  MACHINES IN OPERATION                           |
|                                                  |
|  [!] Probat P12 Roaster         Status: WARNING   |
|      Running: 1,248.5 hrs | Temp: 78°C (High)     |
|      Current Billing: $1,120 (Revenue-Indexed)   |
|      [ Schedule Free Warranty Service > ]        |
|                                                  |
|  [*] BrewPro 500 Keg Line       Status: OPTIMAL  |
|      Running: 412.0 hrs  | Normal Operation      |
|      Current Billing: $480 (Fixed Lease)         |
+--------------------------------------------------+
|  [ (Dashboard) ]    [ (Fleet) ]    [ (Payments) ]|
+--------------------------------------------------+
```

### 2.3 Screen C: Vector Signature Capture Modal
```
+--------------------------------------------------+
|  E-Sign Lease Master Agreement       Step 3 of 3 |
+--------------------------------------------------+
|  By signing below, you agree to dynamic ACH debit|
|  terms and grant UCC-1 collateral security lien. |
|                                                  |
|  +--------------------------------------------+  |
|  | x  Maya Lin                                |  |
|  |    (Draw signature with finger or pen)     |  |
|  +--------------------------------------------+  |
|  [ Clear ]                      [ View Full PDF ]|
|                                                  |
|  [ [v] Complete & Authenticate with FaceID ]     |
+--------------------------------------------------+
```

---

## 3. Tactile & Haptic Feedback Rules
* **Barcode Capture:** `HapticFeedback.mediumImpact()` upon successful QR/Barcode decode.
* **Lease Approval:** `HapticFeedback.heavyImpact()` accompanied by green status banner slide-down.
* **Slider Adjustments:** `HapticFeedback.selectionClick()` on every 6-month increment change.