/// Identifies exactly which build is running, so a field report can be tied
/// to a version. vercel-build.sh passes the same id it uses for the
/// cache-busted URLs (--dart-define=BUILD_ID=...), so the number shown in the
/// menu matches the ?v= in the app's URLs. Local builds say "dev".
const String kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');
