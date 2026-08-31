import 'package:flutter/material.dart';

import '../../cloud/nexus_cloud.dart';
import '../../widgets/ui_bits.dart';
import '../app_shell.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    if (!cloud.ready) {
      return const PageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!cloud.isSignedIn) return const LoginPage();
    if (!cloud.emailVerified) return const VerifyEmailPage();
    return const AppShell();
  }
}
