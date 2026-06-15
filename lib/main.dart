import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/profile_settings_sheet.dart';
import 'services/auth_session.dart';
import 'services/bound_device_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HB Sales POS',
      debugShowCheckedModeBanner: false,
      home: const _SessionGate(),
    );
  }
}

/// Restores persisted login payload before choosing the first screen.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final restored = await AuthSession.restoreFromStoredLoginPayload();
    if (restored) {
      final deviceId = await getSavedDeviceIdForLogin();
      if (deviceId != null && deviceId.trim().isNotEmpty) {
        AuthSession.deviceUuid = deviceId.trim();
      }
    }

    if (!mounted) return;
    final hasToken =
        AuthSession.accessToken != null && AuthSession.accessToken!.isNotEmpty;
    setState(() {
      _home = restored && hasToken
          ? const ProfileSettingsScreen()
          : const LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _home ??
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
  }
}
