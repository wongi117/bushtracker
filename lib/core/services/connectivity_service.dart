import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ConnectivityState {
  final bool isConnected;
  final String connectionType;
  final DateTime? lastChecked;
  final DateTime? lastOnline;

  const ConnectivityState({
    this.isConnected = false,
    this.connectionType = 'checking',
    this.lastChecked,
    this.lastOnline,
  });
  
  String get statusText {
    if (connectionType == 'checking') return 'CHECKING';
    if (!isConnected) return 'OFFLINE';
    switch (connectionType) {
      case 'wifi':
        return 'WIFI';
      case 'mobile':
        return 'MOBILE';
      case 'ethernet':
        return 'ETHERNET';
      case 'vpn':
        return 'VPN';
      default:
        return 'ONLINE';
    }
  }

  String get lastOnlineText {
    if (lastOnline == null) return '';
    final diff = DateTime.now().difference(lastOnline!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
  
  Color get statusColor {
    if (connectionType == 'checking') return Colors.orange;
    if (!isConnected) return Colors.red;
    if (connectionType == 'wifi') return Colors.green;
    if (connectionType == 'mobile') return Colors.orange;
    return Colors.green;
  }

  IconData get statusIcon {
    if (connectionType == 'checking') return Icons.sync;
    if (!isConnected) return Icons.wifi_off;
    if (connectionType == 'wifi') return Icons.wifi;
    if (connectionType == 'mobile') return Icons.signal_cellular_alt;
    return Icons.wifi;
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  Timer? _checkTimer;

  ConnectivityNotifier() : super(const ConnectivityState(
    isConnected: false,
    connectionType: 'checking',
    lastChecked: null,
  )) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _checkConnectivity();
    _checkTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    state = ConnectivityState(
      isConnected: state.isConnected,
      connectionType: 'checking',
      lastChecked: state.lastChecked,
      lastOnline: state.lastOnline,
    );

    try {
      // Ping OpenRouter — any response (even 401) means internet is up
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
      ).timeout(const Duration(seconds: 5));

      final connected = response.statusCode < 500;
      state = ConnectivityState(
        isConnected: connected,
        connectionType: connected ? 'wifi' : 'none',
        lastChecked: DateTime.now(),
        lastOnline: connected ? DateTime.now() : state.lastOnline,
      );
    } catch (_) {
      // Fallback: try Google
      try {
        await http.get(
          Uri.parse('https://www.google.com'),
        ).timeout(const Duration(seconds: 4));
        state = ConnectivityState(
          isConnected: true,
          connectionType: 'wifi',
          lastChecked: DateTime.now(),
          lastOnline: DateTime.now(),
        );
      } catch (__) {
        state = ConnectivityState(
          isConnected: false,
          connectionType: 'none',
          lastChecked: DateTime.now(),
          lastOnline: state.lastOnline,
        );
      }
    }
  }

  void setConnectionStatus(bool connected, String type) {
    state = ConnectivityState(
      isConnected: connected,
      connectionType: type,
      lastChecked: DateTime.now(),
      lastOnline: connected ? DateTime.now() : state.lastOnline,
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});