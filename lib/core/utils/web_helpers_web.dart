// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

Future<void> downloadBytes(String filename, List<int> bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrl(blob);
  (html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click())
      .remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> openSmsUrl(String body) async {
  html.window.open('sms:?body=${Uri.encodeComponent(body)}', '_blank');
}

Future<void> shareText(String title, String text) async {
  try {
    html.window.navigator.share({'title': title, 'text': text});
  } catch (_) {}
}

bool get isWebPlatform => true;

void registerWebView(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int id) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow = 'fullscreen; geolocation';
      return iframe;
    },
  );
}
