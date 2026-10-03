# Pinage Maps / BushTrack — working notes for Claude

Offline survival and field navigation app. Flutter, Android first, web build secondary.
Future Gen AI Pty Ltd (Dennis Simmons), Leonora, Western Australia.

**This app is for places with no signal.** That is not a feature, it is the premise. Any
change that only works online is wrong until it also works offline, and anything that implies
it did something it could not do — sent an SOS, saved a photo, found your position — is a
safety problem, not a UX one.

---

## 1. Where things are

**The real source is `C:\Projects\bush_track`.** Copies under Desktop or Downloads are stale;
do not edit them.

```
lib/
  core/
    models/           waypoint, geofence, trail, field_file, artifact, breadcrumb,
                      photo_paths_codec
    services/         database_service (SQLite), photo_capture_service, gpx_service,
                      waypoint_share_service, heading/ (compass + sensor fusion)
    utils/            geo_geometry, startup_trace
    config/           api_config — every key, all via String.fromEnvironment
  features/
    ar/               camera overlay: projection, targets, pin sheet, photo viewer
    dashboard/        the map screen. Large. Most map UI lives here.
    files/            projects ("field files"), notes, search
    geofence/         boundaries/zones: drawing, categories, provider
    map/              markers, editors, offline map manager, visibility, locate/heading
    tracking/         location provider, GPS smoothing, track target
    mesh/             peer-to-peer over Nearby Connections (SOS relay)
    ai/               chat, vision identify, offline knowledge
    navigation/       bush-mode straight-line navigation
api/                  Vercel serverless proxies (gemini, groq, vision) — keep keys server-side
test/                 ~343 tests. See §6.
PINAGE_BUILD_PLAN_4.md  current phase plan and task checklist
```

## 2. Stack

- Flutter 3.41 / Dart 3, Riverpod (`StateNotifier` and `StateProvider`)
- `flutter_map` 6.2.1 + latlong2 for the map; MapTiler tiles; `maplibre_gl` for 3D
- `sqflite` on device, `sqflite_common_ffi_web` on web — **see §4**
- `geolocator`, `sensors_plus`, `camera`, `image_picker`, `flutter_tts`,
  `nearby_connections`, `permission_handler`
- **Supabase** (project `pinage-maps`, ap-southeast-2 Sydney) — approved, not yet integrated.
  Arrives with Phase 4.4. Config lives in `api_config.dart`.

## 3. Rules that are not negotiable

### Secrets
- Every key goes through `String.fromEnvironment` in `lib/core/config/api_config.dart`.
  Never inline a key anywhere else.
- **The Supabase service-role key must never be in the app**, in any form. The publishable
  key is safe in the client *only because RLS is on every table* — if RLS is ever off, that
  key is a data leak.
- **Scan every tracked file before a push, `.md` and docs included.** A live Vercel token once
  sat in `VERCEL_DEPLOYMENT.md` and GitHub's push protection caught it. A scan of `lib/` and
  `api/` alone would have missed it.
- Never use GitHub's "unblock secret" link to force a blocked push. Remove the secret.
- Do not print the git remote URL: it has a PAT embedded in `.git/config`.

### Tokens and where they live
- `config/pinage.json` is **git-ignored** and holds the Mapbox public token and the Mapillary
  access token. `config/pinage.example.json` is the committed template.
- Build with `--dart-define-from-file=config/pinage.json`. Without it the app still runs: no
  Mapbox token keeps the map on MapTiler, no Mapillary token hides the imagery layer.
- A Mapbox **secret** token (`sk.`) goes in the **user-level** gradle properties file,
  `~/.gradle/gradle.properties` (on this PC, under `C:/Users/User/.gradle/`), as
  `MAPBOX_DOWNLOADS_TOKEN`. **Never `android/gradle.properties` — that one is tracked by
  git.** Most Mapbox guides say "gradle.properties" without saying which, and that is how an
  sk. leaks.
- Mapillary has two tokens and they are not interchangeable: the **client** token returns
  `{"data":[]}` with HTTP 200, the **access** token returns real imagery. Empty-with-200 means
  the wrong credential, not thin coverage.

### Mapbox tiles are billed per request
Mapbox raster tiles through flutter_map are supported by Mapbox's terms and
**billed per tile request** (25,000 MAU free on the mobile SDKs; raster tiles are
counted separately). Esri and OSM were free, so nothing in this app was ever
written with request cost in mind. Things that cost money quietly:

- **`{r}`, never a hardcoded `@2x`.** flutter_map fills `{r}` with `@2x` on a
  high-density screen and nothing otherwise — one request either way. With
  `@2x` written into the URL and no `{r}`, flutter_map instead *simulates*
  retina by requesting **four tiles at a higher zoom and combining them**, so
  every tile becomes four already-doubled requests and the top zoom level is
  lost. This was shipped and fixed; do not undo it.
- **`panBuffer` is fetches, `keepBuffer` is memory.** `panBuffer` pre-loads
  rings of tiles beyond the screen that may never be looked at — keep it at 1.
  `keepBuffer` only retains tiles already fetched, so it is free and worth
  having generous: it stops re-paying for ground you have already panned over.
- **Never add Mapbox to the offline downloader.** Caching their tiles outside
  their own SDK is not permitted, and bulk download would be both a terms
  breach and a large bill. Offline regions stay on the other sources until the
  Protomaps work lands.
- **Do not rebuild the TileLayer needlessly.** A changing `key` or a URL
  rebuilt with a new string identity re-fetches every visible tile.
- **The tile cache is a performance cache, not offline maps.** `tile_cache.dart`
  caches to disk so the app stops re-paying for tiles it already has, including
  across restarts. Three rules it must keep:
  - `CachePolicy.request`, **never** `forceCache`. The library's default saves
    every successful GET whatever the response headers say; `request` caches
    only what the provider's own directives permit. `maxStale` stays null, so
    nothing outlives the expiry the provider set.
  - It is capped (`TileCache.maxBytes`) and prunes oldest-first, because the
    file store has no limit of its own and a map cache will happily eat the
    space a field phone needs for photos.
  - It is **not** a substitute for offline regions, and the settings row says so
    in words. Mapbox offline stays SDK-only.
  The cache is warmed up in `main()` before the map builds: handing the
  TileLayer a different provider later re-fetches every visible tile.
- Esri remains selectable for field comparison only. Its licence is unresolved
  — see PINAGE_BUILD_PLAN_4.md 5.5.

### Supabase
- Only ever the `pinage-maps` project in Sydney. **Never `autoplexity-ai`** — that is a
  different product in a different repo that happens to share an owner.
- RLS enabled on every table, no exceptions. Visibility is enforced in the database, not in
  the UI.
- Heritage and protected-zone data stays on the device and syncs only to the Sydney project.
  Never public, never a third party. This is a governance rule, not a preference.

### Safety-critical honesty
- SOS must say **"QUEUED — NOT SENT"** until delivery is confirmed. A false sense of having
  called for help is worse than a clear failure.
- Plant and rock identification must never claim something is safe. `IdentifySafety` has no
  "safe" value on purpose.
- With no GPS fix, show no coordinates. The app once displayed Uluru as the user's position.
- With no compass heading, draw no arrow. An arrow is a claim about direction.

### Git
- Do not push without explicit approval. Commits are fine.
- `deploy.ps1` pushes first — deploy with `npx vercel --prod --yes` alone.

## 4. Traps that have already cost a day each

**sqflite platform split.** Android and iOS must use the sqflite *plugin*;
`databaseFactoryFfi` is desktop-only. Forcing FFI meant the database never opened on the
phone at all. See `native_db_factory_io.dart`.

**Lists in a SQLite column.** `photo_paths` was `join(',')`/`split(',')`, and every base64
data URI contains a comma — so one photo read back as two broken fragments. Use
`PhotoPathsCodec` (JSON), never a naive join.

**Hand-rolled model copies.** `updateWaypointColor` rebuilt a `Waypoint` field by field and
silently dropped `fileId`, `rating` and `weatherConditions` when they were added later. Use
`copyWith`.

**Bearings are circular.** Never average them as plain numbers: 350° and 10° average to 180°,
pointing south while you drive north. Sum unit vectors. This bug has appeared twice.

**The compass has two different answers.** `HeadingReading.degrees` is the bearing of the
handset's *top edge* — right for a map compass rose held flat, and degenerate when the phone
is held up, because the top edge points at the sky. `cameraDegrees` is where the *lens*
points, for AR. They are not interchangeable; using the wrong one made AR markers travel with
the camera.

**`viewInsets` is the keyboard; `viewPadding` is the navigation bar.** Handling only the first
draws your buttons underneath the second.

**Schema migrations exist now** -- `DbMigrations`, currently version 5, one transaction per
step, every step idempotent. Two rules that are easy to break:

* A fresh install runs `_createTables` **and then `markFresh`**, which replays every
  migration. `CREATE TABLE` deliberately does not chase the newest columns; the migrations
  are the single source. So a test that builds a schema from `createTablesForTest` alone is
  testing a schema the app never runs on -- use `attachForTest` plus `markFresh`.
* A migration must check before it touches anything, including the columns it *reads*.
  Migration 5 backfilled `sort_order` from `created_at` without checking that column existed;
  on a handset without it the step threw, the transaction rolled back, and the database stayed
  at version 4 -- retrying and failing the same upgrade on every launch, with nothing on
  screen saying why.

**Unsorted is a view, not a row.** `FieldFile.unsortedId` is `-1` and is *never* written to
`file_id`; unfiled work is `file_id IS NULL`. Writing `-1` would file items under a project
that does not exist, hiding them from every project list **and** from the Unsorted view. Any
code comparing `fileId == file.id` has to special-case it -- `-1` matches nothing.

**An empty filter must mean "everything".** `ProjectScope` collapses an empty selection to
"show all" and is not able to represent "show nothing". On a field phone a pin that is not
drawn reads as lost work, not as filtered, so a blank map is never an acceptable state to
land in by accident -- and a deleted project must be pruned out of any scope.

**GeoJSON coordinates are `[longitude, latitude]`.** The spec's order, the opposite of how
this app and every person says it. Backwards, a Leonora export is a valid file that opens
without complaint somewhere off Somalia. Polygon rings must also be closed (last position
repeats the first) or some readers accept the file and others reject it.

**An async restore can clobber a tap.** A `StateNotifier` that loads from SharedPreferences in
its constructor will overwrite anything the user did in the first few frames. `MarkerVisibility`
records that the user has acted and the restore defers to it. Anything else that restores
state this way has the same hole.

**`downloadBytes` swallows write errors** (`catch (_) {}`) and writes into the app's documents
directory, which no Android file manager can reach. So the old import/export screen can report
a successful export when nothing was written and the user could not find it anyway. Share the
file instead, and check it exists and is non-empty first.

**Flutter test font is monospace-square.** Text measures nearly twice its real width, so
layout tests at 360 px fail on things that fit fine in reality. Assert widths, not ellipsis.

## 5. The device

Samsung, wireless adb only — **USB does not work on this phone**. The port rotates constantly;
ask for a fresh one rather than guessing.

```
adb connect 192.168.1.210:<port>
flutter build apk --release --dart-define=DEBUG_AR=true
adb -s 192.168.1.210:<port> install -r build/app/outputs/flutter-apk/app-release.apk
adb -s <device> logcat -d | grep flutter
```

- `--split-per-abi` writes `app-arm64-v8a-release.apk`; a plain build writes
  `app-release.apk`. Installing the wrong one re-installs a stale build.
- Check the APK's timestamp against the newest `.dart` before installing.
- `DEBUG_AR=true` logs heading, pitch, roll, lens bearing and per-pin screen positions.
- It is a canvas app: drive it by screenshots and coordinates, not DOM selectors.

## 6. Testing

`flutter test` — **343 passing, 10 known failures, all in `test/widget_test.dart`** (screen
smoke tests that predate this work). Any other failure is yours.

`flutter analyze lib` must report **zero errors**. There are ~90 pre-existing info/warning
lints in untouched files; do not let a new error hide among them — grep for `error -`.

Every feature must pass an **airplane-mode test on the phone**, including a cold start, before
it counts as done.

## 7. How to work here

- Small commits, one per task. Update the checklist in `PINAGE_BUILD_PLAN_4.md` as you go.
- Write the test that would have caught the bug, not a test that restates the fix. Several
  real design flaws in this codebase were found by a test disagreeing with the implementation
  — believe the test and look again.
- Measure before claiming a cause. Filter tuning, startup time and GPS accuracy have all been
  diagnosed wrongly here by arithmetic done in the head, then corrected by a logcat line.
- Say what is unverified. Code that analyses and tests clean but has not been on the phone is
  not finished, and should be reported that way.
