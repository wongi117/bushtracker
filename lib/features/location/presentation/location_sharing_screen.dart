import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/location/services/location_sharing_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationSharingScreen extends ConsumerStatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  ConsumerState<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends ConsumerState<LocationSharingScreen> {
  Duration _selectedDuration = LocationSharingService.fourHours;
  bool _isSharing = false;
  String? _sharingToken;
  DateTime? _sharingExpiry;

  @override
  Widget build(BuildContext context) {
    final locationSharingService = ref.watch(locationSharingServiceProvider);
    final locationState = ref.watch(locationProvider);

    _isSharing = locationSharingService.isSharing;
    _sharingToken = locationSharingService.sharingToken;
    _sharingExpiry = locationSharingService.sharingExpiry;

    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    final hasGPS = lat != null && lon != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHARE MY LOCATION'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panelMatte,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasGPS
                      ? AppColors.statusGreen.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      hasGPS ? Icons.my_location : Icons.location_searching,
                      color: hasGPS ? AppColors.statusGreen : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hasGPS ? 'Your Current Location' : 'Acquiring GPS...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    hasGPS
                        ? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}'
                        : 'Step outside for a GPS fix',
                    style: TextStyle(
                      color: hasGPS ? Colors.white54 : Colors.orange,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Share your live location with someone tracking you from home. They receive a link that updates every few minutes.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Active sharing status
            if (_isSharing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.cell_tower, color: AppColors.statusGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'LIVE LOCATION SHARING ACTIVE',
                        style: TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panelLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            'bushtrack.app/live/${_sharingToken ?? '---'}',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppColors.primaryOrange, size: 18),
                          tooltip: 'Copy link',
                          onPressed: _copyLink,
                        ),
                      ]),
                    ),
                    if (_sharingExpiry != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Expires in: ${_formatExpiryTime(_sharingExpiry!)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('STOP SHARING', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _stopSharing,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Duration selection
            const Text('SELECT DURATION',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'How long should your location be visible to the link holder?',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panelMatte,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                _buildDurationOption(LocationSharingService.oneHour, Icons.timer, '1 Hour',
                    'Good for a short trip or day walk'),
                _buildDurationOption(LocationSharingService.fourHours, Icons.timer_3, '4 Hours',
                    'Recommended for full-day outings'),
                _buildDurationOption(LocationSharingService.eightHours, Icons.schedule, '8 Hours',
                    'Long expeditions or overnight trips'),
                _buildDurationOption(LocationSharingService.untilStopped, Icons.lock_open, 'Until I Stop',
                    'Continuous sharing — you control when it ends'),
              ]),
            ),

            const SizedBox(height: 20),

            // Start sharing button
            if (!_isSharing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.cell_tower),
                  label: const Text('START SHARING MY LOCATION',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: hasGPS ? _startSharing : _showNoGPSWarning,
                ),
              ),

            const SizedBox(height: 24),

            // Share via section
            const Text('SHARE LINK VIA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'Send the sharing link to someone who can track you. They do not need the app.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildShareButton(
                  Icons.message, 'SMS', Colors.green, _shareViaSms)),
                const SizedBox(width: 10),
                Expanded(child: _buildShareButton(
                  Icons.copy, 'Copy Link', AppColors.primaryOrange, _copyLink)),
                const SizedBox(width: 10),
                Expanded(child: _buildShareButton(
                  Icons.chat_bubble, 'WhatsApp', const Color(0xFF25D366), _shareViaWhatsApp)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption(Duration duration, IconData icon, String label, String subtitle) {
    final isSelected = _selectedDuration == duration;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? AppColors.primaryOrange : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryOrange) : null,
      onTap: () => setState(() => _selectedDuration = duration),
    );
  }

  Widget _buildShareButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _showNoGPSWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No GPS fix yet — step outside and wait a moment.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _startSharing() {
    final service = ref.read(locationSharingServiceProvider);
    final token = service.startSharing(_selectedDuration);
    setState(() {
      _isSharing = true;
      _sharingToken = token;
      _sharingExpiry = _selectedDuration == LocationSharingService.untilStopped
          ? null
          : DateTime.now().add(_selectedDuration);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live location sharing started. Share the link below.'),
        backgroundColor: AppColors.statusGreen,
      ),
    );
  }

  void _stopSharing() {
    final service = ref.read(locationSharingServiceProvider);
    service.stopSharing();
    setState(() {
      _isSharing = false;
      _sharingToken = null;
      _sharingExpiry = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location sharing stopped.')),
    );
  }

  void _copyLink() {
    final token = _sharingToken ?? 'demo-token';
    final link = 'https://bushtrack.app/live/$token';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: AppColors.primaryOrange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareViaSms() async {
    final token = _sharingToken ?? 'demo-token';
    final link = 'https://bushtrack.app/live/$token';
    final body = Uri.encodeComponent('Track my live location: $link');
    final uri = Uri.parse('sms:?body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS not available on this device')),
      );
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final token = _sharingToken ?? 'demo-token';
    final link = 'https://bushtrack.app/live/$token';
    final text = Uri.encodeComponent('Track my live location: $link');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available — link copied to clipboard')),
      );
      _copyLink();
    }
  }

  String _formatExpiryTime(DateTime expiry) {
    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours > 24) return 'Indefinite';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}
