class AppSecrets {
  static const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
  static const String maptilerKey = String.fromEnvironment('MAPTILER_KEY');
  
  static const String geminiKey = String.fromEnvironment('GEMINI_KEY');
  static const String googleProjectName = 'projects/147600682787';
  static const String googleProjectNumber = '147600682787';
  static const String googleModelName = 'gemma-4-31b-it';

  static String maptilerTileUrl(String style, String format) {
    return 'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.$format?key=$maptilerKey';
  }

  static String maptilerStyleUrl(String style) {
    return 'https://api.maptiler.com/maps/$style/style.json?key=$maptilerKey';
  }
}
