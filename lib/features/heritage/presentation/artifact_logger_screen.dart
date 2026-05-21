import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:bush_track/core/models/artifact.dart';
import 'package:bush_track/features/heritage/providers/artifact_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/utils/web_helpers.dart';
import 'package:bush_track/core/services/artifact_pdf_service.dart';
import 'package:bush_track/theme/app_colors.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

class ArtifactLoggerScreen extends ConsumerStatefulWidget {
  const ArtifactLoggerScreen({super.key});

  @override
  ConsumerState<ArtifactLoggerScreen> createState() =>
      _ArtifactLoggerScreenState();
}

class _ArtifactLoggerScreenState extends ConsumerState<ArtifactLoggerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.history_edu, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('ARTIFACT LOGGER', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.add_location_alt), text: 'Log'),
            Tab(icon: Icon(Icons.list_alt), text: 'Survey'),
            Tab(icon: Icon(Icons.view_in_ar), text: 'AR View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _LogTab(),
          _SurveyTab(),
          _ArReviewTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Log new artifact ─────────────────────────────────────────────────

class _LogTab extends ConsumerStatefulWidget {
  const _LogTab();

  @override
  ConsumerState<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<_LogTab> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _dimCtrl = TextEditingController();
  final _geologistCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _material = 'Stone';
  String _condition = 'Good';
  bool _signedOff = false;
  final List<String> _photos = [];
  bool _saving = false;

  static const _materials = ['Stone', 'Bone', 'Ceramic', 'Metal', 'Wood', 'Shell', 'Other'];
  static const _conditions = ['Excellent', 'Good', 'Fair', 'Poor', 'Fragment'];

  @override
  void dispose() {
    _labelCtrl.dispose();
    _dimCtrl.dispose();
    _geologistCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo capture requires the mobile app.')),
      );
      return;
    }
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
    if (xfile == null) return;
    setState(() => _photos.add(xfile.path));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final stats = ref.read(locationProvider).stats;
    setState(() => _saving = true);
    try {
      final artifact = Artifact(
        label: _labelCtrl.text.trim(),
        materialType: _material,
        dimensions: _dimCtrl.text.trim().isEmpty ? null : _dimCtrl.text.trim(),
        condition: _condition,
        fieldNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        latitude: stats.currentLat,
        longitude: stats.currentLon,
        altitude: stats.currentAltitude,
        photoPaths: List.from(_photos),
        geologist: _geologistCtrl.text.trim().isEmpty ? null : _geologistCtrl.text.trim(),
        signedOff: _signedOff,
        createdAt: DateTime.now(),
      );
      await ref.read(artifactProvider.notifier).addArtifact(artifact);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Artifact "${artifact.label}" logged with GPS pin.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
        _labelCtrl.clear();
        _dimCtrl.clear();
        _geologistCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _material = 'Stone';
          _condition = 'Good';
          _signedOff = false;
          _photos.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(locationProvider).stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // GPS status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stats.currentLat != null
                  ? AppColors.statusGreen.withValues(alpha: 0.15)
                  : AppColors.statusRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: stats.currentLat != null
                    ? AppColors.statusGreen.withValues(alpha: 0.5)
                    : AppColors.statusRed.withValues(alpha: 0.5),
              ),
            ),
            child: Row(children: [
              Icon(
                stats.currentLat != null ? Icons.gps_fixed : Icons.gps_off,
                color: stats.currentLat != null
                    ? AppColors.statusGreen
                    : AppColors.statusRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                stats.currentLat != null
                    ? 'GPS locked: ${stats.currentLat!.toStringAsFixed(5)}, ${stats.currentLon!.toStringAsFixed(5)}'
                    : 'No GPS fix — artifact will be saved without coordinates.',
                style: TextStyle(
                  color: stats.currentLat != null
                      ? AppColors.statusGreen
                      : AppColors.statusRed,
                  fontSize: 12,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Label
          _field('Artifact Label *', _labelCtrl,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
          const SizedBox(height: 12),

          // Material type
          _label('Material Type'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _materials
                .map((m) => ChoiceChip(
                      label: Text(m),
                      selected: _material == m,
                      onSelected: (_) => setState(() => _material = m),
                      selectedColor: AppColors.accent.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                          color: _material == m ? AppColors.accent : AppColors.textMuted),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Dimensions
          _field('Dimensions (e.g. 12×8×4 cm)', _dimCtrl),
          const SizedBox(height: 12),

          // Condition
          _label('Condition'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _conditions
                .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: _condition == c,
                      onSelected: (_) => setState(() => _condition = c),
                      selectedColor: AppColors.primaryOrange.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                          color: _condition == c ? AppColors.primaryOrange : AppColors.textMuted),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Field notes
          _field('Field Notes', _notesCtrl, maxLines: 3),
          const SizedBox(height: 12),

          // Geologist sign-off
          _field('Geologist Name (optional)', _geologistCtrl),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Geologist Sign-Off',
                style: TextStyle(color: Colors.white)),
            value: _signedOff,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => setState(() => _signedOff = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          // Photos
          _label('Photos'),
          const SizedBox(height: 8),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photos[i]),
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 24),

          // Save
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.save_alt),
              label: Text(_saving ? 'Saving...' : 'LOG ARTIFACT + GPS PIN'),
              onPressed: _saving ? null : _save,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? Function(String?)? validator, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        validator: validator,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.panelMatte,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ]);
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600));
}

// ─── Tab 2: Survey list + export ─────────────────────────────────────────────

class _SurveyTab extends ConsumerWidget {
  const _SurveyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(artifactProvider);
    final artifacts = state.artifacts;

    return Column(children: [
      // Export bar
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.panelMatte,
                  foregroundColor: AppColors.accent),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF Report'),
              onPressed: artifacts.isEmpty
                  ? null
                  : () => _exportPdf(context, artifacts),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.panelMatte,
                  foregroundColor: AppColors.textSecondary),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export CSV'),
              onPressed: artifacts.isEmpty
                  ? null
                  : () => _exportCsv(context, artifacts),
            ),
          ),
        ]),
      ),

      if (state.isLoading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (artifacts.isEmpty)
        const Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_edu_outlined, size: 56, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('No artifacts logged yet.',
                  style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
        )
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: artifacts.length,
            itemBuilder: (ctx, i) => _ArtifactCard(
              artifact: artifacts[i],
              onDelete: () =>
                  ref.read(artifactProvider.notifier).deleteArtifact(artifacts[i].id!),
            ),
          ),
        ),
    ]);
  }

  Future<void> _exportPdf(BuildContext context, List<Artifact> artifacts) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArtifactPdfService.exportReport(artifacts);
      messenger.showSnackBar(const SnackBar(
        content: Text('PDF report exported'),
        backgroundColor: Color(0xFF4CAF50),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('PDF export failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _exportCsv(BuildContext context, List<Artifact> artifacts) {
    const header =
        'ID,Label,Material,Dimensions,Condition,Latitude,Longitude,Altitude,Geologist,SignedOff,Notes,Created\n';
    final rows = artifacts.map((a) {
      return [
        a.id,
        _q(a.label),
        _q(a.materialType ?? ''),
        _q(a.dimensions ?? ''),
        _q(a.condition ?? ''),
        a.latitude ?? '',
        a.longitude ?? '',
        a.altitude ?? '',
        _q(a.geologist ?? ''),
        a.signedOff ? 'Yes' : 'No',
        _q(a.fieldNotes ?? ''),
        a.createdAt.toIso8601String(),
      ].join(',');
    }).join('\n');
    final csv = header + rows;
    final filename = 'artifacts_${DateTime.now().millisecondsSinceEpoch}.csv';
    downloadBytes(filename, utf8.encode(csv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported $filename'),
        backgroundColor: AppColors.statusGreen,
      ),
    );
  }

  String _q(String s) => '"${s.replaceAll('"', '""')}"';
}

class _ArtifactCard extends StatelessWidget {
  final Artifact artifact;
  final VoidCallback onDelete;

  const _ArtifactCard({required this.artifact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.panelMatte,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: artifact.signedOff
              ? AppColors.statusGreen.withValues(alpha: 0.4)
              : AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.history_edu, color: AppColors.accent, size: 22),
        ),
        title: Text(artifact.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${artifact.materialType ?? ''} · ${artifact.condition ?? ''}'
          '${artifact.latitude != null ? ' · GPS' : ''}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (artifact.signedOff)
            const Icon(Icons.verified, color: AppColors.statusGreen, size: 18),
          if (artifact.photoPaths.isNotEmpty) ...[
            const SizedBox(width: 4),
            const Icon(Icons.photo, color: AppColors.textMuted, size: 16),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.statusRed, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title: const Text('Delete Artifact?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove "${artifact.label}" from the survey log?',
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: AR Review mode ────────────────────────────────────────────────────

class _ArReviewTab extends ConsumerStatefulWidget {
  const _ArReviewTab();

  @override
  ConsumerState<_ArReviewTab> createState() => _ArReviewTabState();
}

class _ArReviewTabState extends ConsumerState<_ArReviewTab> {
  double _compassHeading = 0.0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      magnetometerEvents.listen((e) {
        if (!mounted) return;
        double h = math.atan2(e.y, e.x) * 180 / math.pi;
        if (h < 0) h += 360;
        setState(() => _compassHeading = h);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'AR Review requires the mobile app — camera and compass sensors are not available in a browser.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final artifacts = ref.watch(artifactProvider).artifacts;
    final stats = ref.watch(locationProvider).stats;
    final currentLat = stats.currentLat;
    final currentLon = stats.currentLon;

    if (currentLat == null || currentLon == null) {
      return const Center(
        child: Text('Waiting for GPS…',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return Stack(children: [
      // Dark background simulating camera view
      Container(color: Colors.black),
      // AR overlay
      CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ArtifactArPainter(
          artifacts: artifacts,
          currentLocation: LatLng(currentLat, currentLon),
          heading: _compassHeading,
        ),
      ),
      // HUD
      Positioned(
        bottom: 16,
        left: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Heading: ${_compassHeading.toInt()}° · ${artifacts.length} artifact(s) logged',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
    ]);
  }
}

class _ArtifactArPainter extends CustomPainter {
  final List<Artifact> artifacts;
  final LatLng currentLocation;
  final double heading;

  const _ArtifactArPainter({ // ignore: prefer_const_constructors_in_immutables
    required this.artifacts,
    required this.currentLocation,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const fov = 60.0;
    final centerX = size.width / 2;

    final bgPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF7B2FFF).withValues(alpha: 0.9);
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFB300);

    final visible = artifacts
        .where((a) => a.latitude != null && a.longitude != null)
        .where((a) {
      final bearing = _bearing(currentLocation,
          LatLng(a.latitude!, a.longitude!));
      double rel = bearing - heading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;
      return rel.abs() <= 35;
    }).toList();

    for (final artifact in visible) {
      final target = LatLng(artifact.latitude!, artifact.longitude!);
      final bearing = _bearing(currentLocation, target);
      final distance = _dist(currentLocation, target);

      double rel = bearing - heading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;

      final screenX = centerX + (rel / (fov / 2)) * (size.width / 2);
      final norm = (distance / 500).clamp(0.0, 1.0);
      final pinTop = size.height * (0.1 + norm * 0.35);

      final distText = distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} km'
          : '${distance.toStringAsFixed(0)} m';

      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '${artifact.label}\n',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '${artifact.materialType ?? ''} · $distText',
            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10),
          ),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);

      const pH = 10.0;
      const pV = 6.0;
      final bW = tp.width + pH * 2;
      final bH = tp.height + pV * 2;
      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(screenX - bW / 2, pinTop, bW, bH),
        const Radius.circular(10),
      );

      bgPaint.color = const Color(0xFF0D0F1E).withValues(alpha: 0.88);
      canvas.drawRRect(bubbleRect, bgPaint);
      canvas.drawRRect(bubbleRect, borderPaint);
      tp.paint(canvas, Offset(screenX - tp.width / 2, pinTop + pV));

      final stemTop = Offset(screenX, pinTop + bH);
      final stemBot = Offset(screenX, pinTop + bH + 28);
      canvas.drawLine(stemTop, stemBot, stemPaint);

      bgPaint.color = const Color(0xFFFFB300);
      canvas.drawCircle(stemBot, 6, bgPaint);
      bgPaint.color = Colors.white;
      canvas.drawCircle(stemBot, 2.5, bgPaint);
    }
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    double b = math.atan2(y, x) * 180 / math.pi;
    return (b + 360) % 360;
  }

  static double _dist(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
