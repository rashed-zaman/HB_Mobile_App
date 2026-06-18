import 'package:flutter/material.dart';
import 'dart:async' show unawaited;

import '../services/auth_session.dart';
import '../services/pos_settlement_service.dart';
import '../services/pos_shift_status_watcher.dart';
import '../services/pos_sign_in_helper.dart';
import '../services/pos_shift_service.dart';
import '../settlement/settlement_preview_screen.dart';
import 'login_screen.dart';
import 'main.dart' show POSScreen;
import 'settings_screen.dart';

/// Opens the Profile & Settings panel (modal sheet) from the POS burger menu.
Future<void> showProfileSettingsSheet(BuildContext context) {
  // Refresh shift flags so Sign off reflects manager acceptance.
  unawaited(PosShiftStatusWatcher.instance.refresh());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => const _ProfileSettingsSheet(),
  );
}

/// Full-screen variant used when this view is opened as a page route.
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _ProfileSettingsContent()),
    );
  }
}

class _ProfileSettingsSheet extends StatelessWidget {
  const _ProfileSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _ProfileSettingsContent(scrollController: scrollController),
        );
      },
    );
  }
}

class _ProfileSettingsContent extends StatefulWidget {
  const _ProfileSettingsContent({this.scrollController});

  final ScrollController? scrollController;

  @override
  State<_ProfileSettingsContent> createState() => _ProfileSettingsContentState();
}

class _ProfileSettingsContentState extends State<_ProfileSettingsContent> {
  bool _isSigningIn = false;
  bool _isSigningOff = false;
  bool _isSettling = false;
  bool _isLoadingShiftStatus = false;
  final PosShiftStatusWatcher _statusWatcher = PosShiftStatusWatcher.instance;
  final PosShiftService _posShiftService = PosShiftService();
  final PosSettlementService _settlementService = PosSettlementService();

  PosShiftStatus? get _shiftStatus => _statusWatcher.status;

  bool get _operationsEnabled => AuthSession.deviceShiftOperationsEnabled;

  bool get _canSubmitSettlement {
    if (!_operationsEnabled) return false;
    final status = _shiftStatus;
    if (status == null) return !_isLoadingShiftStatus;
    return status.canSubmitSettlement;
  }

  bool get _canSignOff {
    if (!_operationsEnabled || _isSigningOff) return false;
    final status = _shiftStatus;
    if (status == null) return true;
    return status.canEndBilling;
  }

  String? get _signOffHint => _shiftStatus?.signOffBlockedReason;

  String? get _settlementHint {
    final status = _shiftStatus;
    if (status == null || !_operationsEnabled) return null;
    if (status.pendingSettlement) {
      return 'Settlement submitted. Waiting for manager approval.';
    }
    if (status.settlementAccepted && !status.canSubmitSettlement) {
      return 'Settlement accepted. You can sign off when ready.';
    }
    if (status.settlementRequired && !status.canSubmitSettlement) {
      return 'Settlement is not available right now.';
    }
    return null;
  }

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMuted = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _statusWatcher.addListener(_onShiftStatusChanged);
    _refreshShiftStatus();
  }

  void _onShiftStatusChanged() {
    if (!mounted) return;
    if (_statusWatcher.consumeSettlementAcceptedNotification()) {
      _notifySettlementAccepted();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthSession.fullname?.trim().isNotEmpty == true
        ? AuthSession.fullname!.trim()
        : (AuthSession.username ?? 'User');

    return Column(
      children: [
        _buildSheetHeader(context, canClose: _operationsEnabled),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildProfileHeader(name),
              const SizedBox(height: 20),
              _InfoCard(
                icon: Icons.business_outlined,
                label: 'Organization',
                value: AuthSession.organization,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.account_tree_outlined,
                label: 'Business Unit',
                value: AuthSession.businessUnit,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.store_mall_directory_outlined,
                label: 'Outlet',
                value: AuthSession.outlet,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.storefront_outlined,
                label: 'Store',
                value: AuthSession.store,
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Operations'),
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Invoicing',
                enabled: _operationsEnabled,
                onTap: () => _openPosScreen(context),
              ),
              _MenuTile(
                icon: Icons.manage_search_outlined,
                label: 'Bill search',
                enabled: _operationsEnabled,
                onTap: () => _onMenuTap(context, 'Bill search'),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Cash control'),
              _MenuTile(
                icon: Icons.payments_outlined,
                label: 'Settlement',
                enabled: _canSubmitSettlement && !_isSettling,
                loading: _isSettling || _isLoadingShiftStatus,
                onTap: () => _onSettlementTap(context),
              ),
              if (_operationsEnabled &&
                  _settlementHint != null &&
                  !_isLoadingShiftStatus)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 4),
                  child: Text(
                    _settlementHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              _MenuTile(
                icon: Icons.login_outlined,
                label: 'Sign in',
                enabled: !_operationsEnabled && !_isSigningIn,
                onTap: () => _performPosSignIn(context),
              ),
              _MenuTile(
                icon: Icons.logout_outlined,
                label: 'Sign off',
                enabled: _canSignOff,
                loading: _isSigningOff || _isLoadingShiftStatus,
                onTap: () => _performSignOff(context),
              ),
              if (_operationsEnabled &&
                  _signOffHint != null &&
                  !_canSignOff &&
                  !_isLoadingShiftStatus)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 4),
                  child: Text(
                    _signOffHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const _SectionLabel('System'),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Setting',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _LogoutButton(onPressed: () => _logout(context)),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textMuted,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSheetHeader(BuildContext context, {required bool canClose}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Text(
              'Profile & Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            onPressed: canClose ? () => _maybePop(context) : null,
            icon: Icon(
              Icons.close,
              color: canClose ? _textDark : const Color(0xFFC7C7CC),
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
    final initials = _initials(name);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFE8EEF8),
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B5998),
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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

  Future<void> _performPosSignIn(BuildContext context) async {
    if (_isSigningIn || _operationsEnabled) return;

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
            context,
            request.validationError ?? 'Sign in validation failed.',
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
          context,
          result.message?.trim().isNotEmpty == true
              ? result.message!.trim()
              : 'Sign in failed. Please try again.',
        );
        return;
      }

      if (result.raw != null) {
        AuthSession.applyPosSignInPayload(result.raw!);
      } else {
        AuthSession.setShiftStatus(true);
      }

      if (!mounted) return;
      setState(() {});
      await _refreshShiftStatus();
      if (!mounted) return;
      _showSnack(context, 'Sign in successful.');

      _navigateToPosScreen(context);
    } on PosShiftException catch (error) {
      if (!mounted) return;

      if (error.debug != null) {
        await _showPosSignInDebugDialog(error.debug!);
      }

      _showSnack(context, error.message);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPosScreen(BuildContext context) {
    if (!_operationsEnabled) return;
    _navigateToPosScreen(context);
  }

  void _navigateToPosScreen(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const POSScreen()),
      (route) => false,
    );
  }

  static void _onMenuTap(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onSettlementTap(BuildContext context) async {
    if (_isSettling || !_canSubmitSettlement) return;
    setState(() => _isSettling = true);

    try {
      // 1. Submit settlement
      final submitResult = await _settlementService.submitSettlement();

      if (submitResult.shiftStatus != null) {
        _statusWatcher.applyStatus(submitResult.shiftStatus!);
      } else {
        AuthSession.applyShiftStatusFlags(
          pendingSettlement: submitResult.pendingSettlement,
          settlementAccepted: false,
        );
      }

      // 2. Fetch the full slip for printing
      final slip =
          await _settlementService.getSettlementById(submitResult.settlementId);

      if (!mounted) return;

      await _refreshShiftStatus();

      // Show slip preview full-screen; keep the sheet underneath so closing
      // preview returns here instead of a blank route.
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SettlementPreviewScreen(slip: slip, autoPrint: true),
        ),
      );

      if (!mounted) return;
      await _refreshShiftStatus();
    } on PosSettlementException catch (e) {
      if (!mounted) return;
      _showSettlementError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      _showSettlementError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSettling = false);
      if (mounted) await _refreshShiftStatus();
    }
  }

  static void _showSettlementError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Settlement Failed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshShiftStatus({bool silent = false}) async {
    if (!_operationsEnabled) {
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (!silent && mounted) setState(() => _isLoadingShiftStatus = true);
    try {
      await _statusWatcher.refresh(notify: false);
      if (!mounted) return;
      if (_statusWatcher.consumeSettlementAcceptedNotification()) {
        _notifySettlementAccepted();
      }
      setState(() {});
    } finally {
      if (mounted && !silent) setState(() => _isLoadingShiftStatus = false);
    }
  }

  void _notifySettlementAccepted() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settlement accepted. You can now sign off.'),
        backgroundColor: Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<bool> _confirmSignOff(BuildContext context, String terminalCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End billing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text('End billing on $terminalCode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'End billing',
              style: TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static void _showSignOffError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Sign off failed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOff(BuildContext context) async {
    if (_isSigningOff || !_operationsEnabled) return;

    final request = await resolvePosSignInRequest();
    if (!request.isValid) {
      if (!mounted) return;
      _showSignOffError(
        context,
        request.validationError ?? 'Sign off validation failed.',
      );
      return;
    }

    final terminalCode = request.terminalCode!.trim();
    if (!await _confirmSignOff(context, terminalCode)) return;

    setState(() => _isSigningOff = true);
    try {
      final result = await _posShiftService.signOut(
        employeeId: request.employeeId!,
        terminalCode: terminalCode,
      );

      if (mounted) {
        await _showPosSignInDebugDialog(result.debug);
      }

      if (!result.status) {
        if (!mounted) return;
        _showSignOffError(
          context,
          result.message?.trim().isNotEmpty == true
              ? result.message!.trim()
              : 'Sign off failed. Please try again.',
        );
        return;
      }

      if (result.raw != null) {
        AuthSession.applyPosSignOutPayload(result.raw!);
      } else {
        AuthSession.clearPosSignIn();
      }

      if (!mounted) return;
      await _statusWatcher.refresh();
      setState(() {});

      final data = result.data;
      final orderCount = data?['orderCount'];
      final totalAmount = data?['totalAmount'];
      final countLabel = orderCount != null ? '$orderCount' : '0';
      final amountLabel = totalAmount?.toString() ?? '0';
      _showSnack(
        context,
        'Billing ended. Final today: $countLabel order(s), $amountLabel.',
      );
    } on PosShiftException catch (error) {
      if (!mounted) return;

      if (error.debug != null) {
        await _showPosSignInDebugDialog(error.debug!);
      }

      _showSignOffError(context, error.message);
      await _refreshShiftStatus();
    } finally {
      if (mounted) setState(() => _isSigningOff = false);
    }
  }

  static void _logout(BuildContext context) {
    _maybePop(context);
    AuthSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  static void _maybePop(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _statusWatcher.removeListener(_onShiftStatusChanged);
    _posShiftService.close();
    _settlementService.close();
    super.dispose();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tileColor = enabled ? const Color(0xFF1A1A2E) : const Color(0xFFC7C7CC);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (enabled && !loading) ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: enabled ? const Color(0xFF8E8E93) : tileColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: tileColor,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A56DB),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? const Color(0xFFC7C7CC) : tileColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFD1D1D6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Log out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE53935),
          ),
        ),
      ),
    );
  }
}
