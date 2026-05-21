import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadBytes(String filename, List<int> bytes) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
  } catch (_) {}
}

Future<void> openSmsUrl(String body) async {
  final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
  try {
    await launchUrl(uri);
  } catch (_) {}
}

Future<void> shareText(String title, String text) async {
  final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
  try {
    await launchUrl(uri);
  } catch (_) {}
}

bool get isWebPlatform => false;

void registerWebView(String viewId, String url) {}
