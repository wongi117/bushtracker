# Pinage Maps — Build Plan 4

Projects, drawing tools, accounts and sharing, AR boundaries, street navigation.

**Status: approved 1 Oct 2026. Building 4.0 → 4.1 → 4.2 → 4.3 → 4.5.**
4.4 (accounts and sharing) and 4.6 (street navigation) are **not** in the approved set.

---

## 0. Step 0 findings — read this first

Step 0 asked me to read four things. Three of them do not exist in this repo:

| Asked for | Found |
|---|---|
| `CLAUDE.md` | **Not present.** No project instructions file at all. |
| `PINAGE_BUILD_PLAN*.md` | **Not present.** This is the first such plan; there is no Phase 1–3 plan to continue from. |
| `CLAUDE_CODE_BRIEF_SOCIAL.md` | **Not present.** |
| Supabase setup | **Not present.** No `supabase_flutter` dependency, no Supabase code anywhere in `lib/`, no project config. |

Two of those change the shape of this plan materially.

### 0.1 The social brief is still not in the repo

Dennis reports having added `CLAUDE_CODE_BRIEF_SOCIAL.md` to the repo root. As of 1 Oct it is
not there, and not anywhere on the machine: I searched `C:\Projects`, Desktop, Downloads,
`NativeTitleOS` and Documents for `*BRIEF_SOCIAL*` and found nothing. The only recently
modified markdown in the repo is this plan. It may not have saved, or it may have landed in
one of the stale copies.

**Nothing approved is blocked by this.** The social brief only bears on 4.4, which is not in
the approved set. §4 below sets out the account model limited to what *this* brief states,
with the extension points the social brief will need marked, and 4.4 stays unstarted until
the brief arrives.

### 0.2 There was no backend; now there is a project (not yet integrated)

The brief asks for RLS policies, which assumes Postgres and Supabase. Today Pinage Maps is
a **local-only Flutter app**: one SQLite database on the handset, no server, no accounts, no
network sync of user data. The only network calls are map tiles, weather, AI proxies and
Nominatim.

So accounts and sharing are not a feature to add to a backend — they are the decision to
*have* a backend. That brings ongoing cost, a privacy and data-sovereignty question that
matters a great deal for heritage data, and an operational burden. It is also the single
largest item in this brief by effort, and everything in §3 (sharing) depends on it.

**Decided.** Supabase project `pinage-maps`, ap-southeast-2 (Sydney). Config is in
`lib/core/config/api_config.dart` behind `String.fromEnvironment`. The `supabase_flutter`
dependency is deliberately **not** added yet: it arrives with 4.4, and an unused dependency
is weight in a 113 MB APK. See §2 for what this settles and what it does not.

---

## 1. Current state

### 1.1 Data model (SQLite, `database_service.dart`, schema version 1)

| Table | Holds | Project link |
|---|---|---|
| `waypoints` | pins, photo pins, track points | `file_id` |
| `geofences` | boundaries/zones, circle and polygon | `file_id` |
| `trails` | recorded tracks | `file_id` |
| `breadcrumbs` | raw position history | none |
| `field_files` | the thing the brief calls a project | — |
| `file_notes` | notes inside a project | `file_id` |
| `map_regions` | downloaded offline tile areas | none |
| `artifacts` | heritage artefact records | none |
| `mesh_peers` | nearby mesh devices | none |
| `app_meta` | storage self-test, boot counter | — |

`waypoints` columns: id, latitude, longitude, altitude, accuracy, speed, label, notes,
timestamp, type, photo_paths, thumbnail_path, color, icon, order_index, is_pin, file_id,
rating, weather_conditions.

**Photos are base64 data URIs inside `waypoints.photo_paths`, stored as a JSON array.**
This matters for §1.3 and for the export work.

### 1.2 What the brief asks for that already exists

Worth knowing before planning work that is already done:

- **Projects already half-exist.** `field_files` is the project table, `file_id` is already on
  waypoints, geofences and trails, new items already file into the active project, and the
  map and AR camera already scope to one project with a filter pill. Phase 4 §1 is therefore
  mostly *completing* this, not starting it.
- **Offline map download is real**, not a stub: `offline_map_manager.dart` downloads MapTiler
  tiles over HTTP with a progress stream and pause/resume states, and `map_regions` records
  them.
- **Search already exists** across pins, waypoints, boundaries, tracks, projects and notes,
  offline, with type chips, fuzzy matching and four sort orders.
- **Boundaries already have** circle and polygon shapes, categories, drag-to-resize, area and
  perimeter maths, project assignment, and tracking-to.
- **Bush-mode straight-line navigation already exists** and is already offline.
- **AR already renders** pins as beams with correct projection, a ground track to a target,
  tappable pins, and a photo viewer.
- **GPX and KML export exist** for waypoints and trails. GeoJSON does not.

### 1.3 Known weaknesses that Phase 4 will expose

1. **Schema version is 1 with no migration path.** Tables are created with
   `CREATE TABLE IF NOT EXISTS` and there is no `onUpgrade`. Every Phase 4 schema change
   needs a real migration runner first, or existing field data is lost on update. **This is
   the first task of Phase 4, before anything else.**
2. **Photos as base64 in a table row.** A 1200px JPEG is ~150–250 KB of base64 per photo, so a
   pin with ten photos is a ~2 MB row read in full every time the waypoint list loads. Project
   export with photos, and background photo upload, both need these on disk with a path in
   the column. Migration required.
3. **No `updated_at` or soft delete on most tables**, both of which sync and conflict
   resolution need.
4. **No stable public IDs.** Rows use autoincrement integers, which collide across devices.
   Sync needs UUIDs.

---

## 2. Decisions — answered, and still open

### Answered 1 Oct

| | Decision |
|---|---|
| **D1 Backend** | Supabase, project `pinage-maps`, ref `wmdfykxwwhulbrjysusi`, **ap-southeast-2 (Sydney)**. Only ever this project — never `autoplexity-ai`. All server schema through Supabase migrations, RLS on every table. |
| **D2 Heritage data** | Stays on the device, syncs only to the Sydney project. Never public, never a third party. |
| **D3 Social brief** | Said to be added; not present. See §0.1. Does not block the approved work. |
| **D4 Routing** | **Valhalla**, offline and on-device. |

Keys: the **publishable** key lives in the client, which is what it is for, and is safe
*only because RLS is on every table*. With RLS off it is a straight read of everyone's data.
The **service-role** key must never be in the app, in any file or any build flag — it bypasses
RLS entirely, and this app has no server of its own to hold it.

### Still open

**D5 — Bulk tile download licensing.** The existing offline map downloader pulls MapTiler
tiles in bulk, and most commercial tile providers restrict or forbid that outside a specific
offline plan. This is already shipping, so it is not a new risk introduced by Phase 4, but
expanding offline maps makes it bigger.
*Recommendation:* check your MapTiler plan's terms for offline/bulk caching before 4.1's
export and offline-map work grows. If the terms do not allow it, the fallback is an
OSM-derived raster source we are licensed to cache, with satellite imagery from a provider
that sells an offline tier. I will not change tile providers without asking.

**D6 — Further paid services.** Supabase and Valhalla are approved. Nothing else is needed for
4.0–4.3 or 4.5. Two things would need your approval if we reach them:
*Recommendation:* (a) **Valhalla tile hosting** — the WA routing pack has to be built from OSM
data and served from somewhere for the phone to download it. Cheapest is static object storage
(Supabase Storage, or a plain bucket) with the pack built offline on a desktop; no routing
server, no per-request cost. (b) **Geocoding for address search** — currently Nominatim, whose
public endpoint has a usage policy that a shipped app technically breaches at volume. Offline
address search within downloaded regions avoids it entirely, which is the direction the brief
already wants.

**D7 — New, found while testing.** On the phone, `Overpass error: Invalid argument(s): No host
specified in URI /api/overpass`. A relative proxy URL is being used on mobile, which has no
origin — the same class of bug `proxyBase` exists to fix, just missed for this one endpoint.
Small, unrelated to Phase 4, and currently making the Overpass lookup fail silently on the
handset.
*Recommendation:* fold it into the next pass rather than interrupting 4.0. Say the word if you
want it sooner.

## 3. Offline-first matrix

Per the brief, every feature with a plain statement of what works with no signal.

| Feature | Offline | Needs a connection |
|---|---|---|
| Projects: create, rename, colour, archive, delete, move items | Fully | Nothing |
| Project export (GPX/KML/GeoJSON + photo zip) | Fully — written to local storage | Nothing |
| Straight-line tool | Fully | Nothing |
| Freehand tool | Fully | Nothing |
| Boundary detail sheet, edit vertices | Fully | Nothing |
| Boundaries in AR | Fully | Nothing |
| Pins, waypoints, photos, tracking in AR | Fully | Nothing |
| Search of my own data | Fully | Nothing |
| Offline map download | Downloaded areas render fully offline | The download itself |
| Address/place search | Within downloaded regions only | Anywhere else |
| Bush-mode navigation | Fully | Nothing |
| Road-mode navigation | Fully, within a downloaded routing pack | Outside a pack |
| Sign-up, first login | — | **Once.** Then cached. |
| Session after first login | Fully — opens and works offline indefinitely | Nothing. Never logged out for lack of signal. |
| Viewing my own data | Fully | Nothing |
| Viewing data shared with me | Only what I have already opened once | First view of new shared content |
| Sharing, connection requests, edits, posts | Queued in an outbox with a pending badge | Delivery |
| Photo capture | Fully — stored locally first | Upload only, in the background |
| Weather | Last reading with its age, e.g. "2 h ago" | A fresh reading |
| SOS | See §9 — queued, with the UI saying so plainly | Actual delivery |
| Connectivity indicator | Always visible | — |

**Cannot be made to work offline, and the plan says so rather than pretending:**
- First sign-up or first login on a device.
- The first view of content someone has just shared with you.
- Fresh weather.
- Actually delivering an SOS, a share, or a photo upload.
- Address search outside a downloaded region.

---

## 4. Schema changes

### 4.1 Prerequisite: a migration runner

Before any of the below. Bump `version`, add `onUpgrade`, and move the existing
`CREATE TABLE IF NOT EXISTS` set to a versioned migration list. Without this, every change
here is data loss on a field phone. Includes a test that a version-1 database with real rows
survives upgrading.

### 4.2 Local (SQLite)

```
-- Projects become first class
field_files
  + uuid TEXT UNIQUE          -- stable across devices
  + colour TEXT               -- project colour
  + archived_at INTEGER
  + updated_at INTEGER
  + owner_uuid TEXT           -- null until accounts
  + deleted_at INTEGER        -- soft delete, for sync

-- Everything that can belong to a project
waypoints, geofences, trails
  + uuid TEXT UNIQUE
  + updated_at INTEGER
  + deleted_at INTEGER
  + created_by_uuid TEXT

-- Photos move out of the row
photos (new)
  id, uuid, waypoint_id, file_path, thumb_path,
  taken_at, caption, bytes, uploaded_at, updated_at, deleted_at

-- The two drawing tools
drawings (new)
  id, uuid, file_id, kind TEXT        -- 'line' | 'freehand'
  name, notes, colour, width REAL,
  points TEXT                          -- JSON [[lat,lon],...]
  created_at, updated_at, deleted_at, created_by_uuid

-- Routing packs
routing_packs (new)
  id, region_name, bbox, file_path, bytes, installed_at, engine, engine_version

-- Outbox for anything that must reach the server later
outbox (new)
  id, kind TEXT, payload TEXT, created_at,
  attempts INTEGER, last_error TEXT, state TEXT  -- queued|sending|failed

-- Cached account + shared content
account_cache (new)      id, user_uuid, display_name, username, avatar_path, session_json, cached_at
shared_cache (new)       id, item_uuid, kind, payload TEXT, shared_by, permission, cached_at
```

An **"Unsorted"** project is created by the migration and every existing item with
`file_id IS NULL` is left as-is but *displayed* under Unsorted, rather than being rewritten.
Nothing is moved on disk, so the migration cannot lose anything.

### 4.3 Server (if D1 = Supabase)

Mirror tables: `profiles`, `projects`, `items` (or one table per kind), `photos`,
`drawings`, `connections`, `shares`, `blocks`, `reports`.

`shares` is the heart of it:
```
shares
  id uuid pk, item_type text, item_uuid uuid,
  owner_id uuid references profiles,
  grantee_id uuid null,        -- a person
  group_id uuid null,          -- or a crew
  is_public boolean default false,
  permission text check (permission in ('view','edit')),
  created_at timestamptz
```

---

## 5. RLS policies (if D1 = Supabase)

Enforced in the database, not the UI, as the brief requires. Default deny on every table.

```
-- Own your own rows
create policy own_items on items
  for all using (owner_id = auth.uid());

-- Read what has been shared with you
create policy shared_read on items for select using (
  exists (
    select 1 from shares s
    where s.item_uuid = items.uuid
      and (s.grantee_id = auth.uid()
           or s.group_id in (select group_id from group_members where user_id = auth.uid())
           or s.is_public)
  )
);

-- Write only with an explicit edit grant
create policy shared_write on items for update using (
  exists (
    select 1 from shares s
    where s.item_uuid = items.uuid
      and s.permission = 'edit'
      and (s.grantee_id = auth.uid()
           or s.group_id in (select group_id from group_members where user_id = auth.uid()))
  )
);

-- Blocks beat shares
create policy not_blocked on items for select using (
  not exists (
    select 1 from blocks b
    where (b.blocker_id = items.owner_id and b.blocked_id = auth.uid())
       or (b.blocker_id = auth.uid() and b.blocked_id = items.owner_id)
  )
);

-- Heritage is never public and never shared by category alone
create policy heritage_restricted on items for select using (
  category <> 'heritage'
  or owner_id = auth.uid()
  or exists (select 1 from shares s
             where s.item_uuid = items.uuid and s.grantee_id = auth.uid())
);
```

### RLS test cases (written as tests, not checked by hand)

1. A can read A's private item; B cannot.
2. A shares view with B: B can select, B cannot update.
3. A shares edit with B: B can update, B cannot delete or re-share.
4. C, shared with nobody, can read nothing of A's.
5. Public share: anyone can select; nobody can update.
6. B blocks A: A can no longer see B's items, and the share row existing does not help.
7. Heritage item: not visible to a crew-wide share, only to a named grantee.
8. A leaves a group: group share no longer grants access.
9. Deleting a share revokes access immediately.
10. A cannot insert a row with `owner_id` set to someone else.

---

## 6. Screens

**New**
- Projects list (replaces/absorbs the Files screen root), with archive and Unsorted
- Project detail: items by type, search within, move, export, show/hide on map
- Move items (multi-select picker)
- Straight-line tool overlay: segment list, lengths, bearings, undo, Done
- Freehand tool overlay: draw/pan toggle, undo, colour, width
- Boundary detail sheet: name, area, perimeter, project, creator, EDIT / SHOW IN AR / TRACK TO / SHARE
- Boundary vertex editor
- Sign up / log in / reset password / verify email
- Profile view and edit
- Find people, connection requests
- Share sheet: who, and view-or-edit
- Shared with me
- Report / block
- Offline maps manager: areas, sizes, update, delete, total storage (extends the existing screen)
- Routing packs manager
- Road navigation: turn list, voice, ETA, reroute
- Conflict resolution: both versions side by side
- Outbox / sync status

**Changed**
- Map: active project indicator, tools menu, connectivity indicator
- AR camera: boundary rendering, inside/outside indicator, boundary tap
- Pin and boundary sheets: SHARE, creator, read-only state when not yours
- Weather overlay: cached age

---

## 7. Phased task list

Build order as given. Each task is a commit; each phase ends with an airplane-mode test on
the phone.

### Phase 4.0 — Foundations (blocking)
- [x] Migration runner, versioned schema, test that a v1 database with rows survives
      — verified on the phone: `DB migrate 1 -> 2`, then 516 waypoints loaded, no
      exceptions, and with no network at the time so also a cold start offline
- [x] UUIDs, `updated_at`, `deleted_at` on all syncable tables, backfilled
- [x] Photos out of table rows and onto disk, with migration of existing base64 — capture writes files too since 7 Oct; 16-photo pin rescued on the phone; airplane-mode cold start passed
- [ ] Connectivity indicator
- [ ] Outbox table and a queue runner with a pending badge

### Phase 4.1 — Projects
- [x] Project colour, archive, rename
- [x] Delete with confirm: "move contents to Unsorted" vs "delete everything"
- [x] Unsorted default
- [ ] Projects as folders, items grouped by type, search within a project
- [x] Move items, single and multi-select
- [ ] One-toggle show/hide (partly exists)
- [x] Export project: GPX, KML, GeoJSON (new), photos as a zip
- [ ] Airplane-mode test

### Phase 4.2 — Drawing tools

_7 Oct: all six items built and unit-tested (81611ad, dff0882, 1ede920, 4c56eb0); built on today's map by decision, Option B left open. None ticked until each has been used on the phone, including an airplane-mode cold start._

- [ ] Straight line: tap points, live per-segment and total length, per-segment bearing, undo, Done
- [ ] Snap to nearby pins and waypoints
- [ ] Edit afterwards: drag, add, remove vertices
- [ ] Freehand: finger draw with the map locked, draw/pan toggle, undo
- [ ] Ramer–Douglas–Peucker simplification with a tolerance in metres, tested for shape fidelity
- [ ] Stored as geographic coordinates, verified across zoom and rotation
- [ ] Airplane-mode test

### Phase 4.3 — Interactive boundaries on the map
- [ ] Tap a boundary for the detail sheet
- [ ] Vertex editing
- [ ] Permission gating stubbed until 4.4, read-only path proven
- [ ] Airplane-mode test

### Phase 4.4 — Accounts, profiles, connections, sharing
**Blocked on D1, D2, D3.**
- [ ] Auth: email, reset, verification, optional Google
- [ ] Cached session, offline open, never logged out for lack of signal
- [ ] Local-to-account migration on first sign-in, with no data loss, tested on a full database
- [ ] Profiles
- [ ] Connections: find, request, accept, decline, remove, block
- [ ] Shares with view/edit
- [ ] Shared with me, showing who shared it
- [ ] Public pins (asked for 7 Oct): shires, rangers and tourism bodies publish pins with photos that any traveller sees, to bring visitors to a town. Needs a decision on who may publish (verified organisations only?), moderation of photos, and that heritage and protected-zone data can never be made public by this route.
- [ ] RLS policies and the ten test cases above
- [ ] Outbox carries shares, requests, edits
- [ ] Conflict resolution UI
- [ ] Report/block, age gate, safety rules (needs the social brief)
- [ ] Airplane-mode test including cold start

### Phase 4.5 — Boundaries in AR
- [ ] Render boundary edges along the ground in the boundary's colour
- [ ] Name and distance to nearest edge
- [ ] Inside/outside indicator
- [ ] Tap for the same detail sheet
- [ ] Cull beyond ~1.5 km and segment-clip to the view for frame rate
- [ ] Heritage hidden without permission, in AR as well as on the map
- [ ] Airplane-mode test

### Phase 4.6 — Street navigation
**Blocked on D4.**
- [ ] Engine integration, offline packs, pack manager
- [ ] Road mode: turn-by-turn, voice, reroute, ETA, distance remaining
- [ ] Mode switch, auto-suggest, keep bush mode untouched
- [ ] Route to nearest road access, then hand to bush mode
- [ ] Airplane-mode test with wifi and data off

---

## 8. Routing provider

Offline routing is a hard requirement, so the field narrows sharply.

| Option | On-device routing | Verdict |
|---|---|---|
| **Valhalla** | Yes — offline tile extracts | **Recommended.** Built for on-device use, OSM data, free, no per-request cost, multimodal. WA extract is practical to ship as a downloadable pack. Cost: engineering time plus the Flutter bridge. |
| **GraphHopper** | Yes — offline Android library | Viable second. Good quality. Check the current licence for the offline library; some editions are commercial. |
| **OSRM** | Not really | Designed as a server. Would mean hosting, so it fails the hard requirement. |
| **Mapbox Navigation SDK** | Partly | Has offline support but it is a paid tier, and MAU pricing grows with users. Keep as an option if Valhalla's integration cost proves too high. |
| **Google Directions/Routes** | No | Online only. Can only ever be an optional online extra, never the core. |

**Licensing flag, as asked:** Google's Maps Platform terms do restrict displaying Google
route data over a non-Google base map. Pinage Maps uses MapTiler satellite and street tiles,
so using Google Directions on our current map would likely breach those terms. **That is my
reading and it needs a lawyer's or Google's confirmation before anyone relies on it** — but it
is another reason not to build the core on Google.

**Cost shape rather than invented numbers:** Valhalla and GraphHopper-offline have no
per-request cost; the cost is engineering and app size. Mapbox and Google charge per request
or per monthly active user, so cost grows with usage — small at a handful of users, material
at thousands. I have not quoted figures because published rates change and I would rather you
check them at the point of decision than trust a number from me.

**Recommendation: Valhalla**, with a WA pack first, and a pack manager so other regions can be
added. It is the only option that satisfies "must route with no signal" without ongoing
per-user cost.

---

## 9. SOS with no signal — what it can and cannot do

The brief asks for this to be stated plainly, and it is the most important paragraph in this
document. **The UI must never imply help has been contacted when it has not.**

**With a connection:** SMS and/or data message to the configured contacts, with position,
accuracy and time. Confirmed sent.

**With no connection:**
1. **Mesh.** Already built: the SOS goes to any Pinage phone in range over Nearby
   Connections, BLE and wifi direct. Range is a few hundred metres at best, so it depends on
   someone being nearby. **This has never been tested on two phones and should not be relied
   on until it has been.**
2. **Queued.** The SOS is stored and sent automatically the moment signal returns. The UI says
   **"SOS QUEUED — NOT YET SENT"** in plain words, with a timestamp and a live state, and keeps
   saying it until delivery is confirmed.
3. **Local alarm/beacon.** Siren and screen flash to attract anyone within earshot.
4. **Device satellite SOS.** Android's native satellite SOS, where the handset supports it, is
   a *hand-off*: we can deep-link the user to the system emergency flow but we cannot send
   through it ourselves and cannot confirm delivery. The plan is to offer the hand-off and say
   exactly that.

**What it cannot do:** reach emergency services with no signal, no mesh peer and no satellite
hardware. The app must say so rather than spin. A false sense of having called for help is
worse than a clear "not sent".

---

## 10. Risks

1. **The backend is the whole of §3.** If D1 stalls, phases 4.0–4.3 and 4.5 can all proceed;
   4.4 cannot, and parts of 4.6 do not care.
2. **Bulk tile download licensing** (D5) may already be a problem for the existing feature.
3. **App size.** A WA routing pack plus offline tiles plus the current 113 MB APK adds up.
   Packs must be downloaded, never bundled.
4. **Conflict resolution is easy to get wrong.** The brief rightly says never silently
   overwrite. That means real UI and real tests, not a last-write-wins shortcut.
5. **Mesh SOS is unproven.** Two-phone testing is outstanding from an earlier phase and
   should happen before anything leans on it.
6. **Photo migration touches every pin.** It needs a dry run and a rollback, on a copy of a
   real field database.
7. **Heritage data governance** (D2) should be settled before any sync is switched on, not
   after.

---

## 11. What I propose to do next

On your approval:

1. Phase 4.0, which is useful whatever you decide about a backend and is a prerequisite for
   all of it.
2. Phase 4.1 projects, then 4.2 drawing tools, then 4.3 boundaries — none of which need a
   server.
3. In parallel, you answer D1–D6 and send the social brief, so 4.4 can start without a stall.

Phase 4.0's migration runner is the one item I would argue for doing regardless: the schema is
at version 1 with no upgrade path, and the next schema change without it loses field data.

---

# Phase 5 — Map providers and street-level imagery

**Status: plan and estimate only, as asked. No provider code written.**
The only thing built so far is token config (§5.1), which was needed either way.

## 5.0 Token audit — the answer to "is there an sk. anywhere?"

**No.** Checked the working tree and **every blob across all 1,699 objects in every commit**,
for `sk.`, `pk.` and `MLY|` literals. Nothing. `lib/core/config/secrets.dart` exists in
history but every value in it is `String.fromEnvironment` — no literals, only a Google project
number, which is not a secret.

**Where the secret token goes:** `C:\Users\User\.gradle\gradle.properties` — the *user-level*
file, outside the repo:

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.your-existing-bushtracker-token
```

**Not** `android/gradle.properties`. That file **is tracked by git** (it currently holds only
`org.gradle.jvmargs` and `android.useAndroidX`), so a token there would be committed. This is
the likeliest way an sk. leaks, because most Mapbox setup guides say "add it to
gradle.properties" without saying which one.

## 5.1 Tokens in config — done

- `config/pinage.json` — **git-ignored**, holds the real values.
- `config/pinage.example.json` — committed template with placeholders.
- `ApiConfig.mapboxPublicToken` / `ApiConfig.mapillaryToken`, both `String.fromEnvironment`
  with **no committed default** — unlike the Supabase publishable key, which is safe by design
  once RLS is on. A Mapbox token is billable and a Mapillary token has no row-level security
  behind it, so neither belongs in the repo.
- Build: `flutter build apk --release --dart-define-from-file=config/pinage.json`
- `ApiConfig.hasMapbox` / `hasMapillary` gate the features. **Absent is a working state:** no
  Mapbox token means the map stays on MapTiler; no Mapillary token means the imagery layer
  hides itself. That is what stops the switch being a flag day.

**Both tokens verified against the live APIs:**

| Check | Result |
|---|---|
| Mapbox satellite tile over Leonora | HTTP 200, 83 KB of JPEG |
| Mapbox styles endpoint | HTTP 200 |
| Mapillary **client** token (`...5b156e38`) | HTTP 200 but `{"data":[]}` — **not usable** |
| Mapillary **access** token (`...d65c278e`) | HTTP 200 with real image ids — **this is the one** |

The client token authenticates and returns nothing; a genuinely bad token returns HTTP 401, so
empty-with-200 means "authenticated, not authorised for this data". Config uses the access
token.

**"Confirm the map is rendering with the Mapbox token" — not done**, because it cannot be done
without starting the switch, which this phase is meant to plan. What is confirmed is that the
token is valid and returns imagery for your area. Rendering follows in stage 1 below, which is
a one-line change.

## 5.2 What the switch actually costs

The key fact, and it is not obvious: **there are two different Mapbox integrations, and they
cost wildly different amounts of work.**

### Option A — Mapbox raster tiles through the existing flutter_map (small)

Add a tile URL. `https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}@2x.jpg90?access_token=...`
slots straight into the `_tileUrls` list beside MapTiler and ArcGIS.

| Area | Change |
|---|---|
| Map layer | One URL in a list. **Half a day.** |
| Pins, boundaries, drawings | **Nothing.** Still flutter_map markers and polygons. |
| AR | **Nothing.** AR never touches the map — it is GPS plus projection maths. |
| Offline downloader | **Nothing**, but it keeps the existing bulk-raster licensing question (D5) rather than solving it. |
| Street map | Unchanged. |

Gets Mapbox imagery on screen next to MapTiler for comparison, with a toggle, and no risk.
**~0.5 day.**

### Option B — the official Mapbox Maps SDK (large)

`mapbox_maps_flutter` is the official SDK binding. It is **a different map widget**, not a
layer for flutter_map. This is what the offline TileStore — the official region download you
actually want — comes with.

| Area | Change | Estimate |
|---|---|---|
| Map widget | Replace `FlutterMap` with Mapbox `MapWidget` in `dashboard_screen.dart`, the busiest file in the app | 2–3 d |
| Pins | Every `Marker` becomes a `PointAnnotation` or style layer: ~6 marker types, photo thumbnails, live distance labels, numbered markers | 3–4 d |
| Boundaries | Circles and polygons become annotations; drag-to-resize handles re-implemented | 2–3 d |
| Camera, rotation, locate modes | Rewire `MapController` to the Mapbox camera. **The heading-up maths changes** — the arrow correction assumes flutter_map's rotation convention | 1–2 d |
| Tap handling | `onTap(point)` becomes queryRenderedFeatures; pin and boundary hit-testing changes shape | 1–2 d |
| Offline downloader | Replace `offline_map_manager.dart` with TileStore. **This is the win**: official, licensed, resumable, real size estimates | 2–3 d |
| Drawing tools (4.2) | Freehand and line tools would need rebuilding against the new widget if built first | +2 d if ordered wrongly |
| Tests | The map-touching tests | 1–2 d |

**Total: 12–19 days**, and it is a rewrite of the busiest screen, with a period where both map
stacks exist side by side.

**Two things to verify before committing to B** — flagging, not asserting:

1. **Mapbox's terms restrict accessing Mapbox-hosted tiles with a non-Mapbox SDK.** If that
   reading is right, Option A is fine for evaluation but not as a permanent arrangement, which
   pushes toward B. It is the mirror of the Google-routes-on-a-non-Google-basemap problem.
   Worth a direct answer from Mapbox.
2. **MAU billing.** 25,000 free monthly active users is generous, but the SDK counts an MAU on
   app open, not on map use. Irrelevant at your scale; worth knowing before a public launch.

### Protomaps / PMTiles for the street map

Street basemaps from PMTiles are **vector** (MVT). flutter_map cannot render vector tiles
natively — it needs `vector_map_tiles`, or MapLibre, which is already a dependency for the 3D
view. Supabase Storage serves HTTP range requests, which is what PMTiles needs, so hosting
works.

| Area | Estimate |
|---|---|
| Build the WA PMTiles extract on the desktop | 1 d (plus a long download) |
| Host in Supabase Storage, verify range requests | 0.5 d |
| Dart PMTiles reader plus vector renderer wired to the map | 3–5 d |
| Offline: the PMTiles file **is** the offline pack — download once, no tile-by-tile scraping, and **no bulk-caching licensing problem at all** | 1 d |

**5.5–7.5 days.** Worth noting this **solves D5**: one licensed OSM-derived file replaces bulk
scraping of someone else's tile server.

### Valhalla (already approved)

Unchanged: on-device, pack built on the desktop, hosted in Supabase Storage. **6–9 days**
including the Flutter bridge and the pack manager. Independent of the map switch.

### Recommended order

1. **Option A now (0.5 d).** Mapbox imagery beside MapTiler, toggle between them, judge it on
   your phone in the field. Nothing can break; MapTiler stays the default.
2. **Get answers on the two verification items** while you are looking at it.
3. **Protomaps street map (5.5–7.5 d)** next if A looks good, because it is additive and
   solves the offline licensing question.
4. **Option B (12–19 d) only if the official offline download is the deciding factor** — and
   schedule it *before* the 4.2 drawing tools, or those get built twice.

## 5.3 Mapillary street-level imagery

Online-only by design, which is the opposite of everything else in this app, so it has to be
unmistakable in the UI rather than quietly failing.

**Measured coverage in your area**, which is the case for the upload phase:

| Area | Images in a ~6–10 km box |
|---|---|
| Leonora | **5** |
| Kalgoorlie | 50+ (hit the query limit) |
| Perth CBD | 45+ |

### Files and packages

No Mapillary Flutter package is needed or worth it — it is two REST calls.

| File | Purpose |
|---|---|
| `lib/features/streetview/services/mapillary_service.dart` | new — coverage query by bbox, nearest-image lookup, image URL fetch |
| `lib/features/streetview/providers/mapillary_provider.dart` | new — layer on/off, cached coverage, connectivity gate |
| `lib/features/streetview/presentation/street_photo_viewer.dart` | new — the viewer |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | a coverage layer and a Tools-menu toggle |
| `lib/core/config/api_config.dart` | done |

Packages: `http` and `flutter_map`, both already present. **Nothing new.**

### Behaviour

- A toggle in the Tools menu. **Greyed out with "needs a connection" when offline**, not
  hidden — hiding it looks like a missing feature; greying it out explains itself.
- Active at zoom 13 and above only: a bbox query at low zoom over WA would ask for a continent.
- Coverage drawn as small dots. Tapping one, or tapping the map with the layer on, opens the
  nearest image within about 50 m.
- The viewer reuses `PinPhotoViewer`'s shape — swipe, pinch, counter — but loads over the
  network, with its own "no connection" state.
- Results cached in memory for the session only. **Deliberately not cached to disk**:
  Mapillary's terms on storing imagery need checking first, and the offline promise this app
  makes about *your* data must not be quietly extended to someone else's photos.

**Estimate: 2–3 days.**

### Future phase — user street-level photo uploads to Mapillary

Lets crews fill the thin regional WA coverage measured above. Needs, in order:

1. **UPLOAD scope** enabled on the Mapillary app (currently READ only).
2. **A real redirect URL** for OAuth — blocked on the Future Gen AI site being live
   (`futuregenai.com.au` is a placeholder; likely `fgai.com.au`).
3. **OAuth login**, replacing the baked-in access token. The current one is a user access
   token: acceptable for reads in development, not what ships for uploads.
4. Queue uploads through the **existing outbox** (Phase 4.0) so photos taken with no signal
   send themselves later — the same machinery as shares and SOS.
5. A consent step. Uploading someone's photos to a Meta-owned service is a decision the person
   who took them has to make deliberately, per photo or per project, never a default.

**Estimate: 4–6 days once the website and OAuth redirect exist.** Not startable before that.

## 5.4 Keeping MapTiler working

Non-negotiable per the brief, and the design above gives it for free:

- MapTiler stays the **default** style; Mapbox is added to the same list.
- `hasMapbox` is false without a token, so any build without `config/pinage.json` behaves
  exactly as today.
- No change to the offline downloader until Protomaps replaces it, so existing downloaded
  regions keep working.
- Nothing is removed until you have compared them on the phone, in the field.

## 5.5 Esri World Imagery licensing — answered, and the answer is a problem

Asked: does Esri World Imagery's licence allow use in a commercial app the way we are
using it, and what account and attribution does it need?

**I am not a lawyer and this is not legal advice.** What follows is what Esri's own published
metadata says, fetched from their APIs rather than recalled, with the inference drawn plainly
so you can take it to them.

### What Esri's own records say

From `server.arcgisonline.com/.../World_Imagery/MapServer?f=json`:

```
copyrightText: Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community
```

From the ArcGIS Online item record (`10df2279f9684e4a9f6a7f08febac2a9`), field `licenseInfo`:

> This work is licensed under the **Esri Master License Agreement**.
>
> **Export:** This layer is **not intended to be used to export tiles for offline**. If you
> would like to export imagery for offline use in ArcGIS applications, you may use the
> World Imagery (for Export) layer, which is intended for this purpose.
>
> **Data Collection and Editing:** This layer may be used **in various ArcGIS apps** to
> support data collection and editing, with the results used internally or shared with
> others, as described for these use cases.

### What that means for us

| Question | Answer |
|---|---|
| Is it an open or free-to-use licence? | **No.** It is the Esri Master License Agreement — a contract between Esri and its customers, not a public licence. |
| Do we have one? | **No.** There is no Esri account, agreement or API key anywhere in this project. |
| Does the stated use case cover us? | **Probably not.** The permitted use is described as "in various ArcGIS apps". Pinage Maps is a Flutter app hitting the REST tile endpoint directly. |
| Are we breaching the offline clause? | **No.** Checked: `offline_map_manager.dart` downloads MapTiler tiles only, never `arcgisonline.com`. Esri imagery is display-only here. That is the one part of this that is clearly fine. |
| What attribution is required? | `Esri, Vantor, Earthstar Geographics, and the GIS User Community` — now shown on the map. |

**Note the attribution had drifted.** I had written "Esri, Maxar, Earthstar Geographics" from
memory; the service now says **Vantor**, because Maxar rebranded. The string is taken verbatim
from the API response, so it cannot quietly go stale again.

### Assessment

The endpoint being reachable without a key is not permission. Esri moved basemap access to
ArcGIS Location Platform with API keys and a free tier some years ago; `server.arcgisonline.com`
is the older unauthenticated path that a great many apps still use, which makes it common but
not thereby licensed. **For a commercial release I would not rely on it.**

### Options, in the order I would consider them

1. **Make Mapbox the default satellite and keep Esri only for comparison.** You already have a
   Mapbox account with an explicit free tier. Smallest change — one line of default state.
   Caveat: this does not resolve the *other* terms question I flagged in 5.2, that Mapbox's
   terms likely restrict serving their tiles through a non-Mapbox SDK, which is what Option A
   does. That points at Option B as the licensed end state for Mapbox.
2. **Get an ArcGIS Location Platform API key.** There is a free tier, and it makes Esri usage
   licensed and explicit rather than incidental. Keeps the imagery you already know, with a
   key in `config/pinage.json` like the others. Needs you to read their current pricing and
   basemap-request allowance, which I will not quote from memory.
3. **Drop Esri entirely** once the field test picks a winner. Simplest legally, and if Mapbox
   looks better over Leonora anyway then the question answers itself.

### What I have not changed

Esri is **still the default**, deliberately. It is what the app has always shipped, the field
comparison needs both sources, and quietly switching the default would undermine the very
test you are about to run. Say which option you want and I will make the change.

**Esri is referenced in four places**, so a switch is not just the one I added:
`satellite_source_provider.dart`, `home_screen_layout.dart`, `map_3d_screen.dart`,
`map_layer_provider.dart`.
