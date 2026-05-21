# Pinage Maps — Feature Specification

## Future Gen AI Pty Ltd | ABN 60 447 071 932 | Leonora, Western Australia

> Living document. Tick off each item as it is built, tested, and merged.
> **App Store and Play Store submission happens ONLY when every feature below is complete and field-tested.**

---

## Status Legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete & tested

---

## ⚠️ Store Submission Rule

**DO NOT submit to Google Play or Apple App Store until:**

- [ ] SOS mesh broadcast is live and tested on two real devices
- [ ] Deadman switch is live and tested in the field
- [ ] All Phase 1–8 features are ticked off
- [ ] Full field test completed in Leonora, WA
- [ ] flutter analyze — zero issues
- [ ] All widget + integration tests passing
- [ ] Privacy policy published
- [ ] App Store / Play Store listings ready

---

## Phase 1 — Core GPS & Offline Maps ✅ COMPLETE

### GPS & Tracking

- [x] Real-time GPS tracking with satellite map overlay
- [x] Breadcrumb trail — records position every 30 seconds automatically
- [x] Background GPS tracking with screen off
- [x] Session start point saved on first launch
- [x] Resume active session on app reopen

### Offline Maps

- [x] Offline map tile caching — works with zero signal
- [x] OSM tile layer (online fallback while offline tiles load)
- [ ] Automatic region detection on first launch
- [ ] Auto-download map tiles for detected region on first launch
- [x] Multiple map styles: Street / Satellite / Topo
- [ ] 3D terrain rendering (MapLibre GL + AWS DEM elevation)

### Permissions

- [x] GPS location permission handling
- [x] Background location permission (Android foreground service)
- [x] Bluetooth / WiFi permissions for mesh

---

## Phase 2 — AI Voice, Survival & Navigation

### AI System — Antigravity

- [x] Full text control of app via AI chat
- [ ] Full voice control via speech_to_text
- [x] AI chat with persistent memory (user name, vehicle, routes, preferences)
- [x] Natural language search: 'nearest water', 'fuel under 50km', 'flat camp spot'
- [ ] Proactive monitoring: sunset alerts, battery saver mode
- [ ] Movement detection with proactive check-in messages

### ⚠️ Deadman Switch — REQUIRED BEFORE STORE SUBMISSION

- [ ] Track last known movement timestamp continuously
- [ ] Detect zero movement for 4 hours
- [ ] Trigger SOS countdown with dismissible warning
- [ ] If not dismissed — auto-activate SOS broadcast
- [ ] Persist deadman state across app restart
- [ ] Field test: confirmed working on real device with no interaction

### Survival Features

- [x] SOS button — instant bearing & distance to start point
- [x] Return navigation — calculates exact reverse bearing to start
- [ ] Camp finder — scores terrain by flatness and water proximity using elevation data
- [ ] Geofences with entry / exit alerts
- [ ] Off-route detection with voice alert when deviation > 100m

### ⚠️ SOS Mesh Network — REQUIRED BEFORE STORE SUBMISSION

- [ ] Google Nearby Connections integration (Bluetooth + WiFi Direct)
- [ ] SOS broadcast payload: GPS coordinates, user ID, timestamp
- [ ] Broadcast to all nearby Pinage Maps devices automatically
- [ ] Relay — each device rebroadcasts to extend range
- [ ] Receiving device shows incoming SOS on map with distance & bearing
- [ ] SOS alert dismissal / acknowledgement
- [ ] Field test: two devices, no mobile signal, SOS received and displayed

### Navigation

- [x] Turn-by-turn navigation with bearing and distance
- [ ] Route options: Direct Track / Sealed Road / Scenic
- [ ] OSRM offline-capable routing engine integration
- [x] Walk time estimates based on distance
- [ ] Voice turn-by-turn guidance (flutter_tts)

---

## Phase 3 — Web Deployment & UI Polish ✅ LIVE

- [x] Progressive Web App deployed at bush-track.vercel.app
- [x] Works in Samsung Chrome browser
- [x] Dark green / amber theme
- [x] Splash screen with fade animation
- [x] Portrait lock
- [x] Guide overlay with conversational Yes / No cards
- [x] Full-screen compass navigation screen
- [x] Coordinate display tiles
- [x] Tracking status badge (live green dot)
- [x] Bottom nav: Compass / Start / SOS buttons

---

## Phase 5 — Enterprise & Heritage Artifact Logger

### Heritage Artifact Logger

- [ ] In-field photo capture with instant GPS pin drop
- [ ] Structured field notes per artifact:
  - [ ] Material type
  - [ ] Dimensions
  - [ ] Condition
  - [ ] Identification status
  - [ ] Geologist sign-off field
- [ ] AR review mode — walk site, see logged artifact pins through camera
- [ ] Sync and export on return to connectivity
- [ ] PDF report export (GPS coordinates + photos + field notes)
- [ ] Government submission format compliance
- [ ] Enterprise licence gate (AUD $2,500/project or $12,000/yr)

### Enterprise API

- [ ] Per-seat licence management
- [ ] Team / org management dashboard
- [ ] Mining sector outreach portal

---

## Phase 6 — AR, Camera & Photo Memory Pins

### Photo Memory Pins

- [x] Attach photos to any waypoint pin
- [x] In-app camera — auto drops GPS pin the moment photo is taken
- [x] Camera or selfie selection before capture
- [x] Label + notes on pin before saving
- [x] Thumbnail generated and stored with pin
- [x] GPS coordinates stamped on photo preview
- [ ] Offline media gallery per pin (tap pin → view all photos)
- [ ] Gallery integration — show map pin icon on photos in camera roll
- [ ] Tap camera roll photo → open Pinage Maps → see exact location
- [ ] Public / private sharing toggle per pin
- [ ] Share pin via mesh or link

### AR Waypoint Overlay

- [x] Point camera at horizon — see all saved pins floating in real space
- [x] Distance labels, names, and photo thumbnails on AR pins
- [x] Works fully offline using GPS + compass + accelerometer
- [x] No ARCore required
- [x] AR pin tap → open full pin details

### AR Virtual Carving

- [ ] Point camera at any surface (rock, tree, ground)
- [ ] Type or voice a name, message, or tag
- [ ] Text textured and blended into surface (naturally worn look)
- [ ] Anchored to exact GPS location — reappears when you return
- [ ] Edit / delete carving
- [ ] Public or private visibility toggle

### Waypoints & Trails

- [x] Drop waypoint with name, category, rating, timestamp
- [x] Tap pin to read all saved info
- [ ] Numbered trail system — points 1, 2, 3, 4 with connecting lines
- [ ] Trail colour picker (solid / dashed / dotted)
- [ ] AI voice guides along created trail with bearing and distance
- [ ] GPX import / export (Garmin, AllTrails, Gaia GPS compatible)
- [ ] KML import / export

### Map Enhancements

- [ ] Contour lines overlay
- [ ] Vehicle profile routing (4WD, motorbike, on-foot)
- [ ] Wikipedia POI for settlements
- [ ] Nearby places: Fuel, Pub, Medical, Water, Camp, Mechanic

---

## Phase 7 — International Launch

- [ ] Geography-agnostic OSM tile switching (Canada, USA, NZ, South Africa)
- [ ] Regional tile server selection on first launch
- [ ] Localisation framework (i18n)
- [ ] App Store / Play Store listings per country

---

## Phase 8 — Team Features & SAR Integration

- [ ] Group mesh network — share position with crew
- [ ] Team waypoint sync over mesh
- [ ] SAR coordination mode — broadcast grid reference to all mesh devices
- [ ] SES / DFES / Police integration pathway
- [ ] Multi-device session view (see your whole team on one map)

---

## Phase 9 — Hardware 🔭 VISION

- [ ] Pinage Maps dedicated hardware device
- [ ] Built-in GPS mesh radio
- [ ] No phone required

---

## Indigenous Language Support (v4+)

- [ ] Nyungar
- [ ] Pitjantjatjara
- [ ] Warlpiri
- [ ] UI string extraction complete

---

## Non-Functional Requirements

### Performance

- [ ] App cold start < 3 seconds on mid-range Android
- [ ] Map tile render < 500ms at 14x zoom
- [ ] GPS lock acquired within 10 seconds outdoors
- [ ] Background GPS battery drain < 3%/hr

### Privacy & Data Sovereignty

- [ ] All user data stored on-device only
- [ ] No analytics or tracking SDK
- [ ] No account required for core features
- [ ] Privacy policy published and linked in app stores

### Testing

- [x] flutter analyze — zero issues
- [x] Widget tests: 13/13 passing
- [ ] Integration tests on real Android device (Leonora WA field test)
- [ ] Integration tests on iPhone
- [ ] Mesh SOS end-to-end test (two devices, no signal)
- [ ] Deadman switch countdown field test
- [ ] Offline map test (airplane mode, remote location)

---

## Phase 4 — App Store & Play Store Submission

### 🔒 LOCKED — Open only when ALL phases above are complete

### Android

- [ ] Release keystore generated & signed AAB
- [ ] ProGuard / R8 minification verified
- [ ] Google Play Console — app listing created
- [ ] Play Store screenshots (Pixel 8 + tablet)
- [ ] Play Store description, categories, content rating
- [ ] Internal testing track upload
- [ ] Production release

### iOS

- [ ] Apple Developer Account enrolled
- [ ] Bundle ID: com.bushtrack.app registered
- [ ] Distribution certificate created
- [ ] Provisioning profile created
- [ ] ExportOptions.plist — Apple Team ID filled in
- [ ] TestFlight build uploaded
- [ ] App Store Connect listing created
- [ ] App Store screenshots (iPhone 15 Pro + iPad)
- [ ] App Store review submission

### Subscriptions — Pro Tier (AUD $9.99/mo or $79/yr)

- [ ] RevenueCat integration for cross-platform subscriptions
- [ ] Free tier feature gates defined
- [ ] Pro tier: AI guide, SOS mesh, advanced routing, deadman switch
- [ ] Paywall screen designed
- [ ] Restore purchases flow

---

## CI/CD

- [x] GitHub Actions — Android AAB build
- [x] GitHub Actions — iOS IPA build
- [x] Vercel — web PWA deploy on push to main
- [ ] Automated flutter test in CI
- [ ] Automated flutter analyze in CI

---

*Pinage Maps — Pin It. See It. Live It.*
*Future Gen AI Pty Ltd | fgai.com.au*
