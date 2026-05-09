# BushTrack Self-Test Protocol

## LIVE WEB PREVIEW — CONFIRMED WORKING

Run BushTrack in Chrome browser (vibe coding mode):
```bash
cd "C:\Users\User\OneDrive\Desktop\bush tracker\bush_track"
flutter run -d chrome
```

Hot reload while running:
- `r` = instant UI update
- `R` = full restart  
- `q` = quit

Known web limitations (expected, not bugs):
- Geolocator not supported on web — use mock data
- Camera/AR not supported on web — show placeholder
- Mesh/Nearby Connections not on web — show offline UI
- Maps use in-memory on web — persistent on mobile

These are NOT errors. Web preview is for UI only.
Mobile APK has full functionality.

After every UI change:
1. Press `r` for hot reload
2. Check Chrome for visual result
3. If correct — build mobile APK
4. `flutter build apk --release`
