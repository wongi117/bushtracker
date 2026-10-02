# Option B — offline satellite via the official Mapbox SDK

Plan only. Nothing here is built. Written so it can start the day you confirm
after the field test.

---

## The thing to understand before choosing

**The blocker is the imagery licence, not the map widget.**

It is tempting to read Option B as "swap `flutter_map` for the Mapbox SDK and
get offline satellite". The renderer is the easy half. The reason offline
satellite needs their SDK at all is that Mapbox's terms only permit their
imagery to be stored for offline use *by their own SDK's offline manager*.
Esri's terms are the same shape. So:

- Any renderer can show satellite **online**. That is Option A, shipped.
- Only the Mapbox SDK can show **Mapbox** satellite offline.
- A different renderer could show satellite offline only with imagery whose
  licence allows it — which Mapbox and Esri do not.

That means Option B is not a free choice of architecture. If you want Mapbox
imagery in a dead zone, their SDK renders the map. Everything below follows
from that.

---

## Three ways to get there

### B1 — Replace `flutter_map` with `mapbox_maps_flutter` everywhere

What it touches, measured in the repo today:

| Thing | Count |
|---|---|
| Files that build a `FlutterMap` | 4 |
| `MarkerLayer` | 21 |
| `PolylineLayer` | 15 |
| `MapController` | 10 |
| `TileLayer` | 8 |
| `CircleLayer` | 6 |
| `PolygonLayer` | 5 |
| `MapOptions` | 4 |

None of these port across. The Mapbox SDK has no widget layers — it has a
style with sources and layers, plus annotation managers, all driven
imperatively through a platform channel. Every marker becomes a
`PointAnnotation` or a `SymbolLayer` with a GeoJSON source; every zone circle
becomes a `CircleLayer` or a computed polygon; tap handling moves from Flutter
hit-testing to the SDK's own gesture callbacks, which means the AR hit-testing
and the nearest-pin logic get rewritten against a different coordinate API.

The non-obvious losses:

- **MapTiler, Esri and the topo layers stop working as base maps.** The SDK
  renders Mapbox styles. Raster sources from elsewhere can be added to a style,
  but the whole base-map switching UI gets rebuilt, and your Esri comparison
  option becomes awkward rather than a one-line URL change.
- **The disk tile cache becomes dead code.** `flutter_map_cache` caches
  `flutter_map`'s HTTP fetches. The SDK has its own cache you do not control
  the same way.
- **Widget tests mostly stop covering the map.** A platform-channel map does
  not render in a Flutter test. Everything currently asserted about layers and
  positions would need either a fake or a device test.

Estimate: **3–4 weeks**, and the first week is all regression with nothing new
to show. Highest risk of the three by a wide margin.

### B2 — Dual map: Mapbox SDK for satellite, `flutter_map` for the rest

The SDK map is instantiated only when the chosen base map is Mapbox satellite
(online or offline); `flutter_map` keeps everything else. Both draw the same
pins, zones and trails.

Cheaper to reach than B1, but it buys a permanent tax: two implementations of
every annotation, two gesture paths, two sets of tap maths, and a class of bug
where a feature works on one base map and not the other. That tax lands on
whoever adds the next map feature, every time, and 4.2 drawing tools would be
the first to pay it.

Estimate: **2 weeks** to working, then slower on every map feature after.

### B3 — Don't migrate; solve offline differently

Keep `flutter_map`. Get offline imagery from a source whose licence permits
storing it:

- **MapTiler**, if your plan's terms allow bulk download and offline storage.
  You said you would check and report back — that answer decides whether this
  option exists, and it is still outstanding.
- **Self-hosted imagery** in Supabase Storage as MBTiles/PMTiles, from a source
  that permits redistribution (Sentinel-2 and Landsat are open; resolution is
  coarser than Mapbox, ~10 m against sub-metre).
- **`maplibre_gl`**, already a dependency for the 3D view, which can hold
  offline regions for any style you are allowed to store.

Estimate: **3–5 days** for a Sentinel-2 pipeline, most of it on the desktop
side generating the pack.

---

## Recommendation

**Field-test first, then B2 only if Mapbox imagery specifically is what wins.**

The field test answers a narrower question than it looks. Not "is Mapbox
better" but:

> At the zoom levels a crew actually works at, in the country they actually
> work in, is Mapbox's imagery enough better than Sentinel-2 to be worth
> rebuilding the map on?

Around Leonora the honest answer may be no. Sub-metre imagery earns its keep on
built-up detail; for scrub, tracks, drainage and old workings, 10 m open
imagery is often as useful, and it can be stored offline without asking anyone.
That is why B3 is on the list rather than being a consolation prize.

So, in order:

1. Field-test Mapbox vs Esri this week, as planned, **and add a third
   comparison**: a Sentinel-2 tile of the same ground. One afternoon to stand
   up, and it is the thing that makes B3 a real option instead of a guess.
2. Get the MapTiler answer. It may make B3 trivial.
3. If Mapbox imagery genuinely wins on ground that matters, do B2 — not B1.
   Scope the SDK to the satellite base map and leave `flutter_map` owning the
   annotations, the tests and the drawing tools.

---

## If you confirm B2, the order of work

Each step ends somewhere shippable, so this can stop between any two.

1. **Token and entitlement.** The `sk.` (DOWNLOADS:READ) stays in
   `~/.gradle/gradle.properties` — user-level, never `android/gradle.properties`,
   which is tracked. The `pk.` continues to come from `config/pinage.json` via
   `--dart-define-from-file`. Add `mapbox_maps_flutter`, confirm a release build
   still comes out, ship nothing. *Half a day.*
2. **A bare SDK map behind a flag.** One screen, Mapbox satellite, no
   annotations, reachable only from the satellite-comparison setting that
   already exists. Proves the channel, the token and the build. *1 day.*
3. **A map interface both widgets satisfy.** `camera`, `move`, `onTap`,
   `bounds`, `project`/`unproject`. Narrow deliberately: everything that can
   stay in Flutter should. *1–2 days.*
4. **Annotations on the SDK path.** Pins first, then zones, then trails, each
   against the same provider lists the `flutter_map` path reads, so the two
   cannot drift on what is shown. The project scope added in 4.1 already
   filters at the provider, which is what makes this feasible. *3–4 days.*
5. **Tap handling and the pin sheet.** The one to be careful with: the nearest-
   pin threshold is in degrees scaled by zoom, and the SDK reports taps
   differently. Port the existing hit-test maths rather than reinventing it, and
   keep the AR path reading the same targets. *2 days.*
6. **Offline regions.** The actual point. The SDK's offline manager, a region
   per project bounding box, progress and failure surfaced in the existing
   downloader UI — and still no Mapbox tiles in the `flutter_map` downloader,
   which is not permitted. *2–3 days.*
7. **Switch the default, keep the escape hatch.** `flutter_map` stays
   selectable for a release or two. The first field trip after this is when the
   bugs turn up. *Half a day.*

### What to decide before step 4

- **Does the SDK path need the drawing tools (4.2)?** If yes, 4.2 waits for
  step 5 and is built once against the interface. If no, 4.2 can start now on
  `flutter_map`. This is the question I need answered before 4.2 begins, and it
  is why that work is on hold.
- **Does 3D stay on `maplibre_gl`?** Two native map SDKs in one app is real
  binary size and two sets of lifecycle bugs. Folding 3D onto the Mapbox SDK is
  a day or two extra and removes a dependency.
- **Heritage data is unchanged by all of this.** Protected-zone geometry stays
  on the device and continues to sync only to the Sydney project. No boundary
  goes into a style, a tileset or anything else that leaves the phone. Worth
  writing into the step-4 work rather than remembering later: an annotation is
  not a tileset, and nothing here changes where that data lives.

---

## Cost note

Option A is billed per tile request, so the disk cache is doing real work.
Option B's offline regions are billed differently again — region downloads
count against a separate allowance from map loads. Before step 6, check the
current pricing page for the tile-pack allowance on the free tier, because
"25k monthly active users" covers map loads and is not the limit that matters
for downloads.
