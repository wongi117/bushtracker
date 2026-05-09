# 🛠️ ANTIGRAVITY MAINTENANCE SYSTEM

## Overview

The Antigravity Maintenance System provides comprehensive tools for managing, monitoring, and maintaining the BushTrack application. This system ensures optimal performance, data integrity, and survival capability in remote environments.

---

## 🔧 Core Maintenance Features

### 1. AI System Maintenance

#### 3-Tier AI Diagnostics
```dart
// Run AI health check
final aiStatus = await aiService.getFullStatus();

// Returns:
// ☁️ Cloud AI: ✅ Online (OpenRouter)
// 📱 On-Device: ✅ Ready (Gemma 2B) / ❌ Web not supported
// 📋 Rule-Based: ✅ Always Available
```

**Features:**
- ✅ Cloud AI connectivity check
- ✅ On-device AI initialization status
- ✅ Rule-based AI template validation
- ✅ Response time monitoring
- ✅ Error rate tracking
- ✅ Automatic fallback verification

**Maintenance Tasks:**
- [ ] Test AI response on startup
- [ ] Verify fallback chain (Cloud → On-Device → Rule-Based)
- [ ] Monitor API rate limits
- [ ] Check on-device model integrity
- [ ] Validate survival template database

---

### 2. Offline Map Management

#### Map Region Storage
```dart
// Check offline map storage
final storage = await offlineMapManager.getStorageUsage();
print('Total: ${storage.formattedSize}, ${storage.regionCount} regions');
```

**Features:**
- ✅ Download map regions for offline use
- ✅ Automatic tile caching
- ✅ Storage usage monitoring
- ✅ Region expiration management
- ✅ Corrupted tile detection

**Supported Map Sources:**
- OpenStreetMap (Standard)
- CARTO Dark (Night mode)
- ESRI World Imagery (Satellite)

**Maintenance Tasks:**
- [ ] Verify downloaded regions integrity
- [ ] Check storage usage (< 5GB recommended)
- [ ] Update expired tiles
- [ ] Clean corrupted downloads
- [ ] Backup critical map regions

---

### 3. Photo Geotagging System

#### Photo Storage Management
```dart
// Check photo storage
final photoInfo = await photoService.getStorageInfo();
print('${photoInfo.photoCount} photos, ${photoInfo.formattedSize}');
```

**Features:**
- ✅ Automatic photo geotagging (EXIF)
- ✅ Thumbnail generation (200x200)
- ✅ GPS metadata extraction
- ✅ Gallery management
- ✅ Storage optimization

**Supported Operations:**
- Take photo with camera (with GPS)
- Pick from gallery (add GPS)
- Extract GPS from existing photos
- Bulk photo import
- Thumbnail caching

**Maintenance Tasks:**
- [ ] Verify photo thumbnails exist
- [ ] Check EXIF metadata integrity
- [ ] Clean orphaned photo files
- [ ] Optimize storage (compress old photos)
- [ ] Backup important waypoint photos

---

### 4. Coordinate System Management

#### Supported Formats

| Format | Example | Use Case |
|--------|---------|----------|
| **Decimal Degrees** | 25.3444° S, 131.0369° E | General navigation |
| **DMS** | 25°20'39.84"S, 131°02'12.84"E | Traditional navigation |
| **UTM** | 52J 281234E 7194321N | Military/surveying |
| **MGRS** | 52J PU 12345 43210 | NATO military |

**Features:**
- ✅ Real-time coordinate conversion
- ✅ Multiple format display
- ✅ Copy to clipboard
- ✅ Share coordinates
- ✅ Emergency services format

**Maintenance Tasks:**
- [ ] Verify conversion accuracy
- [ ] Test all coordinate formats
- [ ] Validate UTM zone calculations
- [ ] Check MGRS grid references

---

### 5. Measurement Tools

#### Distance & Bearing
```dart
// Measure between two points
final distance = CoordinateUtils.calculateDistance(point1, point2);
final bearing = CoordinateUtils.calculateBearing(point1, point2);

// Format: "1.45 km"
// Format: "142.5° SE"
```

#### Area Measurement
```dart
// Calculate polygon area
final area = CoordinateUtils.calculatePolygonArea(polygonPoints);

// Format: "1,245 m²" / "0.12 ha" / "0.001 km²"
```

**Features:**
- ✅ Tap-to-measure distance
- ✅ Bearing calculation with cardinal direction
- ✅ Polygon area measurement
- ✅ Measurement history
- ✅ Export measurements

**Maintenance Tasks:**
- [ ] Verify Haversine formula accuracy
- [ ] Test bearing calculations
- [ ] Validate area calculations
- [ ] Check unit conversions

---

### 6. Database Maintenance

#### SQLite Optimization
```sql
-- Run weekly:
VACUUM;                    -- Reclaim storage
ANALYZE;                   -- Update statistics
REINDEX;                   -- Rebuild indexes

-- Check integrity:
PRAGMA integrity_check;
```

**Features:**
- ✅ Automatic backup
- ✅ Corruption detection
- ✅ Performance optimization
- ✅ Migration support
- ✅ Export/Import

**Tables:**
- `waypoints` - GPS points with photos
- `tracks` - Recorded paths
- `offline_regions` - Downloaded map areas
- `settings` - App configuration
- `ai_interactions` - AI conversation history

**Maintenance Tasks:**
- [ ] Run VACUUM weekly
- [ ] Verify database integrity
- [ ] Check index performance
- [ ] Backup database to external storage
- [ ] Archive old tracks (> 1 year)

---

### 7. GPS & Tracking Maintenance

#### GPS Health Check
```dart
// Verify GPS accuracy
final accuracy = await locationService.checkAccuracy();
// Expected: < 10m in open areas
// Expected: < 50m in forest/canyon
```

**Features:**
- ✅ GPS accuracy monitoring
- ✅ Satellite count display
- ✅ Signal strength indicator
- ✅ Track recording optimization
- ✅ Battery-aware tracking

**Maintenance Tasks:**
- [ ] Verify GPS lock time (< 30s cold start)
- [ ] Check accuracy in various environments
- [ ] Test track recording continuity
- [ ] Validate waypoint accuracy
- [ ] Monitor battery usage

---

### 8. Mesh Network Maintenance

#### Peer Connection Diagnostics
```dart
// Check mesh status
final meshStatus = await meshManager.getStatus();
print('${meshStatus.connectedPeers} peers, ${meshStatus.signalStrength}dBm');
```

**Features:**
- ✅ Nearby device discovery
- ✅ SOS beacon broadcasting
- ✅ Location sharing via mesh
- ✅ Connection quality monitoring
- ✅ Fallback to direct link

**Maintenance Tasks:**
- [ ] Test peer discovery range
- [ ] Verify SOS broadcast functionality
- [ ] Check message delivery rates
- [ ] Monitor connection stability
- [ ] Update mesh protocol version

---

## 📊 System Health Dashboard

### Performance Metrics

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **AI Response Time** | < 2s | 2-5s | > 5s |
| **Map Tile Load** | < 1s | 1-3s | > 3s |
| **GPS Accuracy** | < 10m | 10-50m | > 50m |
| **Database Size** | < 500MB | 500MB-2GB | > 2GB |
| **Photo Storage** | < 1GB | 1-5GB | > 5GB |
| **Battery Usage** | < 10%/hr | 10-20%/hr | > 20%/hr |

### System Checks

Run these checks weekly in survival areas:

```bash
# Automated maintenance script
flutter run --target lib/maintenance/maintenance_runner.dart
```

**Checklist:**
- [ ] ✅ AI connectivity (all tiers)
- [ ] ✅ Offline map availability
- [ ] ✅ GPS lock and accuracy
- [ ] ✅ Database integrity
- [ ] ✅ Photo storage health
- [ ] ✅ Mesh network discovery
- [ ] ✅ Battery optimization
- [ ] ✅ Storage capacity

---

## 🔧 Maintenance Procedures

### Weekly Maintenance (In Field)

1. **AI System Check**
   ```dart
   // Run diagnostics
   await aiService.runDiagnostics();
   ```
   - Test voice recognition
   - Verify all 3 AI tiers
   - Check response templates

2. **Map Validation**
   ```dart
   // Verify offline regions
   await offlineMapManager.validateRegions();
   ```
   - Check downloaded regions
   - Test tile loading
   - Verify storage limits

3. **GPS Calibration**
   - Test in open area
   - Verify accuracy < 10m
   - Check satellite count > 4

4. **Photo Backup**
   - Sync to external storage
   - Verify thumbnails
   - Check EXIF integrity

### Monthly Maintenance (At Base)

1. **Database Optimization**
   ```sql
   VACUUM;
   ANALYZE;
   REINDEX;
   ```

2. **Storage Cleanup**
   - Remove old tracks (> 6 months)
   - Compress large photos
   - Delete unused offline regions

3. **System Update**
   - Check for app updates
   - Update offline maps
   - Refresh survival templates

4. **Backup Creation**
   - Export waypoints (GPX/KML)
   - Backup photos
   - Save settings

---

## 🚨 Emergency Maintenance

### Critical Failure Recovery

**AI System Failure:**
```dart
// Force fallback to rule-based
aiService.forceTier('rulebased');
```

**Database Corruption:**
```dart
// Restore from backup
await databaseService.restoreFromBackup();
```

**GPS Not Locking:**
```bash
# Clear GPS cache
adb shell pm clear com.android.location.fused
```

**Offline Maps Not Loading:**
```dart
// Re-download region
await offlineMapManager.repairRegion(regionId);
```

---

## 📱 Platform-Specific Maintenance

### Android

**Permissions Check:**
```xml
<!-- Required permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.NEARBY_DEVICES" />
```

**Battery Optimization:**
```dart
// Disable battery optimization for location
await Permission.ignoreBatteryOptimizations.request();
```

### iOS

**Background Modes:**
```xml
<!-- Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>bluetooth-central</string>
</array>
```

**Permission Strings:**
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>BushTrack needs your location for survival navigation.</string>
<key>NSCameraUsageDescription</key>
<string>BushTrack uses the camera to geotag photos of waypoints.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>BushTrack uses Bluetooth for mesh networking with nearby devices.</string>
```

---

## 🔒 Security & Privacy

### Data Protection

**Local Data:**
- All data stored locally on device
- No cloud storage (except optional AI)
- Encrypted database (SQLCipher)

**Mesh Network:**
- End-to-end encryption for SOS messages
- Anonymous location sharing
- No personal data transmitted

**Photos:**
- Geolocation stored in EXIF (optional)
- No automatic upload
- User controls all sharing

### Privacy Controls

```dart
// Privacy settings
Settings {
  bool shareLocationInMesh = true;
  bool storePhotoLocation = true;
  bool useCloudAI = true;
  bool sendCrashReports = false;
}
```

---

## 📈 Performance Tuning

### Memory Optimization

```dart
// Optimize for low-memory devices
class MemoryOptimizer {
  static void optimize() {
    // Limit concurrent image loading
    PaintingBinding.instance.imageCache.maximumSize = 100;
    
    // Reduce map tile cache
    tileCache.maxTiles = 512;
    
    // Disable animations on low battery
    if (batteryLevel < 20) {
      disableAnimations();
    }
  }
}
```

### Battery Optimization

**Tracking Modes:**

| Mode | GPS Interval | Battery Usage | Use Case |
|------|--------------|---------------|----------|
| **High** | 1s | ~15%/hr | Emergency/SOS |
| **Normal** | 5s | ~8%/hr | Active hiking |
| **Low** | 30s | ~3%/hr | Casual tracking |
| **Ultra** | 2min | ~1%/hr | Long expeditions |

---

## 🎯 Maintenance Checklist Template

```markdown
## BushTrack Pre-Expedition Checklist

### Date: ___________
### Location: ___________
### Duration: ___________

### System Status
- [ ] AI System: [ ] Cloud [ ] On-Device [ ] Rule-Based
- [ ] Offline Maps: __ regions, __ MB
- [ ] Database: __ MB, __ waypoints
- [ ] Photos: __ photos, __ MB
- [ ] Battery Health: __%

### Functionality Tests
- [ ] Voice AI responds
- [ ] GPS locks in < 30s
- [ ] Offline map loads
- [ ] Photo capture works
- [ ] Mesh discovers peers
- [ ] SOS beacon broadcasts

### Emergency Preparedness
- [ ] Downloaded emergency contacts
- [ ] Offline maps for area
- [ ] Backup battery pack
- [ ] Physical compass backup
- [ ] Emergency whistle

### Sign: ___________
```

---

## 📞 Support & Troubleshooting

### Common Issues

**Q: AI says "System error"**
A: Check internet connection. Falls back to on-device or rule-based AI automatically.

**Q: Map tiles won't load offline**
A: Download the region before going offline. Check storage space.

**Q: GPS accuracy is poor**
A: Move to open area. Wait for satellite lock. Check for interference.

**Q: Photos won't attach to waypoints**
A: Check camera permissions. Verify storage space.

**Q: Mesh network not discovering peers**
A: Enable Bluetooth. Ensure both devices have app open. Check proximity (< 100m).

### Diagnostic Commands

```bash
# Run full diagnostic
flutter run --target lib/maintenance/diagnostics.dart

# Export system state
flutter run --target lib/maintenance/export_state.dart

# Reset to defaults
flutter run --target lib/maintenance/reset.dart
```

---

**Version:** 1.0.0  
**Last Updated:** 2024  
**Maintainer:** Antigravity AI System
