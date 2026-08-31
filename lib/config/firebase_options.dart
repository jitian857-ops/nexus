import 'package:firebase_core/firebase_core.dart';

/// ウェブの API キーは公開前提。実データは Firestore ルールで守る。
/// `--dart-define=FIREBASE_*` があるときはそちらを優先する。
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  static const _fallbackApiKey = 'AIzaSyDYwnQzi_3tYBDnyCTjY-fzF4pSUgJksIE';
  static const _fallbackAppId = '1:814269187296:web:9f0463b0e48fade5a93c85';
  static const _fallbackMessagingSenderId = '814269187296';
  static const _fallbackProjectId = 'nexus-50e0e';
  static const _fallbackAuthDomain = 'nexus-50e0e.firebaseapp.com';
  static const _fallbackStorageBucket = 'nexus-50e0e.firebasestorage.app';
  static const _fallbackMeasurementId = 'G-FS8PJVE037';

  static String get apiKey => _apiKey.isEmpty ? _fallbackApiKey : _apiKey;
  static String get appId => _appId.isEmpty ? _fallbackAppId : _appId;
  static String get messagingSenderId =>
      _messagingSenderId.isEmpty ? _fallbackMessagingSenderId : _messagingSenderId;
  static String get projectId => _projectId.isEmpty ? _fallbackProjectId : _projectId;
  static String get authDomain => _authDomain.isEmpty ? _fallbackAuthDomain : _authDomain;
  static String get storageBucket =>
      _storageBucket.isEmpty ? _fallbackStorageBucket : _storageBucket;
  static String get measurementId =>
      _measurementId.isEmpty ? _fallbackMeasurementId : _measurementId;

  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty && messagingSenderId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      measurementId: measurementId,
    );
  }
}
