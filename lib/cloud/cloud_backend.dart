import 'cloud_models.dart';

abstract class CloudBackend {
  bool get usesFirebase;

  Future<void> init();

  CloudSession? get currentSession;

  Future<CloudSession> signUp({
    required String email,
    required String password,
    required String displayName,
    required String occupation,
  });

  Future<CloudSession> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendVerification();

  Future<CloudSession> confirmVerification({String? code});

  Future<CloudSession> refreshSession();

  Future<void> sendPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<CloudSession> updateProfile({
    required String displayName,
    required String occupation,
  });

  Future<void> deleteAccount({required String password});

  Future<Map<String, dynamic>?> pullLive(String uid);

  Future<void> pushLive(String uid, Map<String, dynamic> bundle);

  Future<void> sealVault(String uid, String reason, Map<String, dynamic> bundle);

  Future<List<VaultRecord>> listVault(String uid);

  Future<VaultRecord?> readVault(String uid, String id);

  Future<List<MailItem>> listMail(String uid);

  Future<void> addMail(String uid, MailItem item);

  Future<void> markMailRead(String uid, String id);
}
