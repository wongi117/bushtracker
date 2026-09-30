# 🌿 BUSHTRACK — Master Feature Roadmap & Implementation Tracker
**Future Gen AI Pty Ltd | ABN 60 447 071 932 | Dennis Simmons, Founder**
*Leonora, Western Australia | bushtrack.netlify.app | Version 3.0 LIVE*

---

## 🏆 What BushTrack Is
AI-powered offline survival navigation for the Australian outback, remote mining regions, and wilderness worldwide.
Built by a First Nations founder who actually survives in this terrain — no competitor can replicate this.

**Unique Position:** Beats Google Maps + Avenza + OsmAnd + Gaia GPS combined on survival features.

---

## ✅ PHASE 1–3: COMPLETE & LIVE

### 🗺️ Core Navigation
- [x] Real-time GPS tracking with satellite map overlay (tested Leonora WA: -28.88875S, 121.33617E)
- [x] Offline map tile caching — works with zero signal
- [x] 3D terrain rendering (MapLibre GL + AWS DEM elevation data)
- [x] Automatic region detection on first launch — AI downloads your area
- [x] Turn-by-turn navigation with 3 route options (Direct / Sealed Road / Scenic)
- [x] Off-route detection with voice alert when user deviates >100m
- [x] Multiple map styles: Street / Satellite / Topo / 3D Terrain

### 🤖 AI System — Antigravity
- [x] Full voice AND text control of entire app
- [x] AI chat with persistent memory (name, vehicle, routes, preferences)
- [x] **Agent Manager** — Switch between specialized personas (Scout, Navigator, Rescue, Tactical)
- [x] Proactive monitoring: sunset alerts, battery saver mode, movement detection
- [x] Deadman switch — zero movement for 4 hours triggers SOS countdown
- [x] Natural language search: "nearest water", "fuel under 50km", "flat camp spot"
- [x] Offline AI fallback using Gemini Nano (on Samsung Galaxy devices)

### 🆘 Survival Features
- [x] Breadcrumb trail — records position every 30 seconds automatically
- [x] Return navigation — AI calculates exact reverse bearing to any past point
- [x] Camp finder — scores terrain by flatness and water proximity using elevation data
- [x] SOS broadcast via Google Nearby Connections mesh network (P2P, no towers)
- [x] AR compass — camera view with floating waypoint direction arrows
- [x] Geofences with entry/exit alerts

### 📍 Waypoints & Trails
- [x] Drop waypoints with full notes (name, category, rating, weather, timestamp)
- [x] Tap saved pin to read all saved information instantly
- [x] Numbered trail creation — drop points 1, 2, 3, 4 with connecting lines
- [x] Trail colour picker: solid / dashed / dotted line styles
- [x] AI voice guides user along trail with bearing + distance
- [x] GPX and KML import/export (Garmin, AllTrails, Gaia GPS compatible)

### 📡 Nearby Places & POI
- [x] Nearby places search: Fuel, Pub, Medical, Water, Camp, Mechanic
- [x] Tested: Leonora BP (34km), Menzies Hotel (45km), Medical Clinic (56km)
- [x] Wikipedia POI integration for settlement information
- [x] Real distance and bearing to every listed place

### 🌐 Web Deployment
- [x] Progressive Web App at bushtrack.netlify.app
- [x] Works in Samsung Chrome browser — no install required
- [x] Android APK (86.7MB) for direct install
- [x] Hot reload dev workflow — UI updates on device in <1 second

---

## 🔄 PHASE 4: IN PROGRESS — Q3 2026

### App Store Launch
- [ ] Google Play Store submission
- [ ] Apple App Store submission
- [ ] App Store Optimisation (ASO) — screenshots, description, keywords
- [ ] Pro subscription launch — AUD $9.99/month or $79/year
- [ ] In-app subscription billing (Google Play Billing / Apple IAP)
- [ ] Free tier vs Pro tier feature gating
- [ ] Onboarding flow for new users (region selection, vehicle profile)

---

## 📋 PHASE 5: PLANNED — Q3 2026

### Enterprise & Government
- [ ] Enterprise API for mining sector (Rio Tinto, BHP, Newmont, Fortescue)
- [ ] Per-seat annual licence system — AUD $499/seat/year
- [ ] Enterprise admin dashboard (team management, fleet tracking)
- [ ] Mining sector outreach campaign (WA Goldfields focus)
- [ ] Government tender preparation
- [ ] Kultju Aboriginal Corporation formal endorsement
- [ ] RED Grant application finalise and submit (up to AUD $50,000)

---

## 📋 PHASE 6: PLANNED — Q4 2026

### Competitor Feature Parity
- [ ] Contour lines overlay on topo map
- [ ] Improved GPX/KML import with track preview
- [ ] Vehicle profiles (4WD, motorcycle, on-foot, horse)
- [ ] Elevation profile graph along selected route
- [ ] Track recording with auto-pause when stationary
- [ ] Magnetic declination correction for compass

---

## 📋 PHASE 7: PLANNED — Q1 2027

### International Launch
- [ ] Canada market launch (Canadian Rockies, remote provinces)
- [ ] USA market launch (Alaska, Utah, Montana wilderness)
- [ ] New Zealand market launch
- [ ] South Africa market launch
- [ ] Localise distance/speed units (km vs miles toggle)
- [ ] Multi-language UI (French-Canadian, Spanish)

---

## 📋 PHASE 8: PLANNED — Q2 2027

### Team & SAR Features
- [ ] Group mesh networking — up to 10 users on one mesh
- [ ] Team member location sharing on map (mesh only, no internet)
- [ ] SAR coordinator view — see all team positions offline
- [ ] Incident reporting with offline photo attachment
- [ ] Radio comms integration (PTT over mesh)
- [ ] Live track sharing via mesh relay

---

## 🔮 PHASE 9: VISION — 2028

### BushTrack Hardware
- [ ] Dedicated GPS mesh device concept
- [ ] Hardware spec: solar charge, satellite modem, 7-day battery
- [ ] LoRa mesh radio integration
- [ ] Rugged enclosure (IP68, drop-rated)
- [ ] OEM partnership exploration

---

## 🌏 Social Impact Commitments

- [x] Free tier permanent — survival navigation is not a luxury
- [ ] Indigenous language support v4: Nyungar, Pitjantjatjara, Warlpiri
- [ ] Kultju Aboriginal Corporation partnership — community product design input
- [x] Data sovereignty — all data on-device, never tracked, never sold
- [ ] Employment priority: Aboriginal Australians in all WA regional hiring
- [ ] 5% of enterprise revenue → remote community digital literacy
- [x] SAR mesh creates safety infrastructure where government cannot reach

---

## 💰 Revenue Targets to Hit

| Stream | Price | Year 1 Target |
|--------|-------|---------------|
| Free downloads | Free | 100,000 downloads |
| BushTrack Pro | $9.99/mo or $79/yr | AUD $240,000 |
| Enterprise licences | $499/seat/yr | AUD $150,000 |
| Government contracts | $50K–$500K | AUD $100,000 |
| **Total Year 1** | | **AUD $490,000** |

**Year 3 Target: AUD $6.8M revenue, AUD $3.9M net profit**

---

## 🔧 Tech Stack Reference

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) — Android + iOS + Web |
| State | Riverpod |
| Database | Isar (offline NoSQL) |
| Maps | flutter_map + MapLibre GL |
| GPS | Geolocator (background tracking) |
| Mesh | Google Nearby Connections (P2P BT/WiFi) |
| AI Cloud | OpenRouter API (300+ models) |
| AI Offline | Gemini Nano (flutter_gemma) |
| Voice In | speech_to_text |
| Voice Out | flutter_tts + Web Speech API |
| Weather | Open-Meteo (free, cacheable) |
| Routing | OSRM (offline-capable) |
| Elevation | AWS Terrarium tiles |
| Deploy | Netlify (web) + APK (Android) |
| CI/Test | flutter analyze + flutter test |

---

## 🎯 Competitive Advantages — Never Let These Slip

1. **Mesh SOS** — P2P emergency broadcast with NO phone towers (nobody else has this)
2. **Deadman Switch** — 4-hour no-movement auto SOS (nobody else has this)
3. **AI Voice Control** — full app control by voice offline (nobody else has this)
4. **Auto Map Download** — detects region on launch and downloads (nobody else does this)
5. **Breadcrumb AI Return** — exact bearing to walk back on (nobody else does this)
6. **Camp Finder AI** — scored terrain analysis (nobody else has this)
7. **First Nations Authenticity** — cannot be copied by any Silicon Valley competitor
8. **Under $5 to build** — extraordinary capital efficiency story for investors

---

## 📞 Key Contacts

| Role | Name / Detail |
|------|--------------|
| Founder / Director | Dennis Simmons |
| Company | Future Gen AI Pty Ltd |
| ABN | 60 447 071 932 |
| Location | Leonora, Western Australia 6438 |
| Website | fgai.com.au |
| Live App | bushtrack.netlify.app |
| Accelerator | InvestX — coaches Justin Lee & Isaiah Baluso |
| Dev Partner | Appetiser Apps (InvestX programme) |
| Endorsement | Kultju Aboriginal Corporation (in progress) |
| AI Dev IDE | Antigravity (AI-native VS Code fork) |

---

*"BushTrack is live. The GPS is tracking. The AI is talking. The mesh is broadcasting.*
*This is not a pitch. This is a product. Come and see it work."*

🌿 **Wandjina principle: caring for Country — knowing your land, reading its signs, keeping your people safe.**
