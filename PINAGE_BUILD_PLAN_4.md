# Pinage Maps — Build Plan 4

Projects, drawing tools, accounts and sharing, AR boundaries, street navigation.

**Status: awaiting approval. No Phase 4 code has been written.**

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

### 0.1 There is no social brief, so accounts cannot be merged with it yet

The brief says accounts/profiles overlap with the social brief and to merge them into one
plan rather than building two account systems. I agree with the instruction, but the social
brief is not in the repo, so I cannot see what it specifies — what a "crew/group" is, what
the public feed rules are, what the age gate requires, or what profile fields it assumes.

**Guessing at it is the one thing that would cause exactly the duplication the instruction
is trying to prevent.** Section 4 below sets out the account model I would build, deliberately
limited to what this brief states, with the extension points the social brief will need
marked. I need the social brief before building any of it.

### 0.2 There is no backend at all

The brief asks for RLS policies, which assumes Postgres and Supabase. Today Pinage Maps is
a **local-only Flutter app**: one SQLite database on the handset, no server, no accounts, no
network sync of user data. The only network calls are map tiles, weather, AI proxies and
Nominatim.

So accounts and sharing are not a feature to add to a backend — they are the decision to
*have* a backend. That brings ongoing cost, a privacy and data-sovereignty question that
matters a great deal for heritage data, and an operational burden. It is also the single
largest item in this brief by effort, and everything in §3 (sharing) depends on it.

**This needs your decision before I write any of it.** See §2.

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

## 2. Decisions I need from you

Numbered so you can answer briefly.

**D1 — Backend.** Supabase as the brief assumes, or something else? Supabase is the fastest
route to accounts + RLS + storage and is what the brief names. It has a free tier and paid
tiers above it; **confirm current pricing at decision time rather than relying on this
document.** Alternatives: self-hosted Postgres (more control, more ops), or PocketBase (single
binary, cheap, no RLS as such). Everything in §3 and the sharing parts of §1 wait on this.

**D2 — Where does heritage data live?** Protected and heritage zones are the most sensitive
data in this app. A hosted US-region database may be unacceptable for it. Options: Supabase
with an Australian region, heritage items pinned local-only and never synced, or self-hosting.
This is a governance question, not a technical one, and I would rather ask than assume.

**D3 — The social brief.** Send it, or confirm you want accounts built to this brief alone and
reconciled later.

**D4 — Routing engine.** See §8. Offline routing is a hard requirement, which rules out
Google Directions as the core. My recommendation is Valhalla. Needs your sign-off because it
affects app size and possibly hosting.

**D5 — Tile licensing for bulk download.** The existing downloader pulls MapTiler tiles in
bulk. Most commercial tile providers restrict or forbid bulk caching outside a specific
offline plan. Before expanding offline maps I should check MapTiler's current terms for your
account tier. Flagging rather than acting: you may already have a plan that permits it.

**D6 — Any paid service or API key**, per your standing rule: I will not add one without
asking. This affects D1, D4 and D5.

---

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
- [ ] Migration runner, versioned schema, test that a v1 database with rows survives
- [ ] UUIDs, `updated_at`, `deleted_at` on all syncable tables
- [ ] Photos out of table rows and onto disk, with migration of existing base64
- [ ] Connectivity indicator
- [ ] Outbox table and a queue runner with a pending badge

### Phase 4.1 — Projects
- [ ] Project colour, archive, rename
- [ ] Delete with confirm: "move contents to Unsorted" vs "delete everything"
- [ ] Unsorted default
- [ ] Projects as folders, items grouped by type, search within a project
- [ ] Move items, single and multi-select
- [ ] One-toggle show/hide (partly exists)
- [ ] Export project: GPX, KML, GeoJSON (new), photos as a zip
- [ ] Airplane-mode test

### Phase 4.2 — Drawing tools
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
