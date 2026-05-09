import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/location/services/location_sharing_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:flutter/services.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 SHARE MY LOCATION'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current location
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panelMatte,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📌 CURRENT LOCATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationState.stats.coordsDecimal,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sharing status
              if (_isSharing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.panelMatte,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryOrange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📡 LIVE LOCATION SHARING ACTIVE',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share link: https://bushtrack.app/live/$_sharingToken',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_sharingExpiry != null)
                        Text(
                          'Expires: ${_formatExpiryTime(_sharingExpiry!)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _stopSharing,
                        child: const Text(
                          '🛑 STOP SHARING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Duration selection
              const Text(
                '⏱️ SELECT DURATION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.panelMatte,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDurationOption(
                      LocationSharingService.oneHour,
                      '⏰ 1 Hour',
                      Icons.timer,
                      isSelected: _selectedDuration == LocationSharingService.oneHour,
                    ),
                    _buildDurationOption(
                      LocationSharingService.fourHours,
                      '⏰ 4 Hours',
                      Icons.timer_3,
                      isSelected: _selectedDuration == LocationSharingService.fourHours,
                    ),
                    _buildDurationOption(
                      LocationSharingService.eightHours,
                      '⏰ 8 Hours',
                      Icons.timer_3,
                      isSelected: _selectedDuration == LocationSharingService.eightHours,
                    ),
                    _buildDurationOption(
                      LocationSharingService.untilStopped,
                      '🔓 Until I Stop',
                      Icons.lock_open,
                      isSelected: _selectedDuration == LocationSharingService.untilStopped,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Start sharing button
              if (!_isSharing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _startSharing,
                    child: const Text(
                      '📡 START SHARING',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Share options
              const Text(
                '📤 SHARE VIA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(Icons.message, '💬 SMS', _shareViaSms),
                  _buildShareOption(Icons.copy, '📋 Copy Link', _copyLink),
                  _buildShareOption(Icons.chat, '📱 WhatsApp', _shareViaWhatsApp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDurationOption(Duration duration, String label, IconData icon, {required bool isSelected}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primaryOrange : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryOrange) : null,
      onTap: () {
        setState(() {
          _selectedDuration = duration;
        });
      },
    );
  }
  
  Widget _buildShareOption(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 32, color: AppColors.primaryOrange),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  void _startSharing() {
    final locationSharingService = ref.read(locationSharingServiceProvider);
    final token = locationSharingService.startSharing(_selectedDuration);
    
    setState(() {
      _isSharing = true;
      _sharingToken = token;
      _sharingExpiry = DateTime.now().add(_selectedDuration);
    });
    
    // Notify AI assistant
    // In a real implementation, we would integrate with the AI assistant here
  }
  
  void _stopSharing() {
    final locationSharingService = ref.read(locationSharingServiceProvider);
    locationSharingService.stopSharing();
    
    setState(() {
      _isSharing = false;
      _sharingToken = null;
      _sharingExpiry = null;
    });
  }
  
  void _shareViaSms() {
    // In a real implementation, this would open the SMS app
    // For now, we'll show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SMS sharing would open here'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _copyLink() {
    if (_sharingToken != null) {
      const link = 'https://bushtrack.app/live/\$_sharingToken';
      Clipboard.setData(const ClipboardData(text: link));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _shareViaWhatsApp() {
    // In a real implementation, this would open WhatsApp
    // For now, we'll show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp sharing would open here'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatExpiryTime(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now);
    if (diff.inHours > 24) {
      return "Indefinite";
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return "${hours}h ${minutes}m";
  }
}