import 'package:flutter/material.dart';

import '../../cloud/nexus_cloud.dart';
import '../../widgets/ui_bits.dart';
import '../app_shell.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  NexusCloud? _cloud;
  var _ready = false;
  var _signedIn = false;
  var _verified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cloud = CloudScope.read(context);
    if (!identical(_cloud, cloud)) {
      _cloud?.removeListener(_onCloud);
      _cloud = cloud;
      _cloud!.addListener(_onCloud);
    }
    _capture(rebuild: false);
  }

  void _onCloud() {
    if (mounted) _capture(rebuild: true);
  }

  void _capture({required bool rebuild}) {
    final cloud = _cloud;
    if (cloud == null) return;
    final ready = cloud.ready;
    final signedIn = cloud.isSignedIn;
    final verified = cloud.emailVerified;
    if (ready == _ready && signedIn == _signedIn && verified == _verified) return;
    if (rebuild) {
      setState(() {
        _ready = ready;
        _signedIn = signedIn;
        _verified = verified;
      });
    } else {
      _ready = ready;
      _signedIn = signedIn;
      _verified = verified;
    }
  }

  @override
  void dispose() {
    _cloud?.removeListener(_onCloud);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const PageScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_signedIn) return const LoginPage();
    if (!_verified) return const VerifyEmailPage();
    return const AppShell();
  }
}
