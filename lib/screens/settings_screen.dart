import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/bound_device_store.dart';
import '../services/device_bind_service.dart';
import '../services/device_id_store.dart';
import '../services/pos_sign_in_helper.dart';
import '../services/pos_shift_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF8E8E93);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _posShiftService = PosShiftService();
  bool _isSigningIn = false;

  @override
  void dispose() {
    _posShiftService.close();
    super.dispose();
  }

  Future<void> _showPosSignInDebugDialog(PosSignInDebugSnapshot snapshot) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('POS sign in debug'),
        content: SingleChildScrollView(
          child: SelectableText(
            snapshot.format(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _performPosSignIn() async {
    if (_isSigningIn) return;

    setState(() => _isSigningIn = true);
    try {
      final request = await resolvePosSignInRequest();

      if (!request.isValid) {
        if (mounted) {
          await _showPosSignInDebugDialog(
            request.toDebugSnapshot(
              error: request.validationError ?? 'Sign in validation failed.',
            ),
          );
          _showSnack(
            request.validationError ?? 'Sign in validation failed.',
            isError: true,
          );
        }
        return;
      }

      final result = await _posShiftService.signIn(
        employeeId: request.employeeId!,
        terminalCode: request.terminalCode!,
        deviceUuid: request.deviceUuid!,
      );

      if (mounted) {
        await _showPosSignInDebugDialog(result.debug);
      }

      if (!result.status) {
        if (!mounted) return;
        _showSnack(
          result.message?.trim().isNotEmpty == true
              ? result.message!.trim()
              : 'Sign in failed. Please try again.',
          isError: true,
        );
        return;
      }

      if (result.raw != null) {
        AuthSession.applyPosSignInPayload(result.raw!);
      } else {
        AuthSession.setShiftStatus(true);
      }

      if (!mounted) return;
      _showSnack('Sign in successful.');
    } on PosShiftException catch (error) {
      if (!mounted) return;

      if (error.debug != null) {
        await _showPosSignInDebugDialog(error.debug!);
      }

      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SettingsScreen.textDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Setting',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SettingsScreen.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SettingsTile(
            icon: Icons.phonelink_setup_outlined,
            label: 'Set Device Id',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SetDeviceIdScreen(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.login_outlined,
            label: 'Sign In',
            enabled: !_isSigningIn,
            trailing: _isSigningIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _performPosSignIn,
          ),
        ],
      ),
    );
  }
}

class SetDeviceIdScreen extends StatefulWidget {
  const SetDeviceIdScreen({super.key});

  @override
  State<SetDeviceIdScreen> createState() => _SetDeviceIdScreenState();
}

class _SetDeviceIdScreenState extends State<SetDeviceIdScreen> {
  final _controller = TextEditingController();
  final _bindService = DeviceBindService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRemoving = false;
  bool _isBound = false;

  bool get _isReadOnly => _isBound || _isSaving || _isRemoving;

  @override
  void initState() {
    super.initState();
    _loadCurrentId();
  }

  Future<void> _loadCurrentId() async {
    final bound = await getBoundDeviceData();
    if (bound != null && bound.isSaved) {
      _controller.text = bound.deviceUuid;
      if (!mounted) return;
      setState(() {
        _isBound = true;
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    _controller.clear();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bindService.close();
    super.dispose();
  }

  Future<void> _showBindDebugDialog(DeviceBindDebugSnapshot snapshot) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device bind debug'),
        content: SingleChildScrollView(
          child: SelectableText(
            snapshot.format(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveDeviceId() async {
    if (!_isBound || _isRemoving || _isSaving) return;

    final deviceUuid = _controller.text.trim();
    if (deviceUuid.isEmpty) {
      _showSnack('No Device Id to remove.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device Id'),
        content: const Text(
          'Are you sure you want to remove this Device Id from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _removeDeviceId(deviceUuid);
  }

  Future<void> _removeDeviceId(String deviceUuid) async {
    setState(() => _isRemoving = true);
    try {
      final message = await _bindService.unbind(deviceUuid: deviceUuid);

      await clearBoundDeviceData();
      await clearDeviceId();
      AuthSession.deviceUuid = null;
      AuthSession.deviceActive = false;

      if (!mounted) return;
      _controller.clear();
      setState(() => _isBound = false);
      _showSnack(message);
    } on DeviceBindException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_isBound) return;

    final value = _controller.text.trim();
    if (value.isEmpty) {
      _showSnack('Device Id is required');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await _bindService.bind(deviceUuid: value);

      if (kDebugMode && mounted) {
        await _showBindDebugDialog(result.debug);
      }

      await setDeviceId(result.data.deviceUuid);
      await saveBoundDeviceData(result.data);
      AuthSession.deviceUuid = result.data.deviceUuid;
      AuthSession.deviceActive = result.data.active;

      if (!mounted) return;
      _controller.text = result.data.deviceUuid;
      setState(() => _isBound = true);
      _showSnack('Device Id saved');
    } on DeviceBindException catch (error) {
      if (!mounted) return;

      if (kDebugMode && error.debug != null) {
        await _showBindDebugDialog(error.debug!);
      }

      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SettingsScreen.textDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Set Device Id',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SettingsScreen.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Device Id',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SettingsScreen.textDark,
                        ),
                      ),
                      const Spacer(),
                      if (_isBound)
                        TextButton(
                          onPressed: (_isRemoving || _isSaving)
                              ? null
                              : _confirmRemoveDeviceId,
                          child: _isRemoving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Remove Device Id',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    readOnly: _isReadOnly,
                    decoration: InputDecoration(
                      hintText: 'Enter Device Id',
                      border: const OutlineInputBorder(),
                      filled: _isBound,
                      fillColor: _isBound ? const Color(0xFFF5F5F7) : null,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _isBound ? null : (_) => _save(),
                  ),
                  if (_isBound) ...[
                    const SizedBox(height: 12),
                    Text(
                      'This device is bound. Use Remove Device Id to unbind.',
                      style: TextStyle(
                        fontSize: 13,
                        color: SettingsScreen.textMuted,
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    onPressed: (_isSaving || _isRemoving)
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD1D1D6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SettingsScreen.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_isSaving || _isRemoving || _isBound)
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      disabledBackgroundColor:
                          const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? SettingsScreen.textDark : const Color(0xFFC7C7CC);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? SettingsScreen.textMuted : color,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? const Color(0xFFC7C7CC) : color,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
