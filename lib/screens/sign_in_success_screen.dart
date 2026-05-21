import 'package:flutter/material.dart';

import '../services/auth_session.dart';

/// Shown after a successful cash-control session sign-in.
class SignInSuccessScreen extends StatelessWidget {
  const SignInSuccessScreen({
    super.key,
    required this.employee,
    required this.outlet,
    required this.terminal,
    required this.signInTime,
  });

  final String employee;
  final String outlet;
  final String terminal;
  final DateTime signInTime;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMuted = Color(0xFF8E8E93);
  static const Color _cardBg = Color(0xFFF2F2F7);
  static const Color _successGreen = Color(0xFF22C55E);

  factory SignInSuccessScreen.fromSession({required DateTime signInTime}) {
    final employee = AuthSession.fullname?.trim().isNotEmpty == true
        ? AuthSession.fullname!.trim()
        : (AuthSession.username ?? '—');
    return SignInSuccessScreen(
      employee: employee,
      outlet: _outletDisplayName(AuthSession.outlet),
      terminal: _terminalFromStore(AuthSession.store),
      signInTime: signInTime,
    );
  }

  static String _outletDisplayName(String outlet) {
    final dash = outlet.indexOf(' - ');
    if (dash > 0) {
      return outlet.substring(dash + 3).trim();
    }
    return outlet;
  }

  static String _terminalFromStore(String store) {
    final emDash = store.indexOf('—');
    if (emDash > 0) return store.substring(0, emDash).trim();
    final dash = store.indexOf(' - ');
    if (dash > 0) return store.substring(0, dash).trim();
    return store;
  }

  static String _formatSignInTime(DateTime time) {
    final hour = time.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'am' : 'pm';
    return '$hour12:$minute $period';
  }

  void _printSignIn(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print sign in — coming soon'),
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
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textDark,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Sign in',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textDark,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E5EA)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: _successGreen,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign in successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 28),
              _DetailsCard(
                rows: [
                  _DetailRow(label: 'Employee', value: employee),
                  _DetailRow(label: 'Outlet', value: outlet),
                  _DetailRow(label: 'Terminal', value: terminal),
                  _DetailRow(
                    label: 'Sign in time',
                    value: _formatSignInTime(signInTime),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8E8ED),
                    disabledBackgroundColor: const Color(0xFFE8E8ED),
                    foregroundColor: _textMuted,
                    disabledForegroundColor: _textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _printSignIn(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Print sign in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SignInSuccessScreen._cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE5E5EA),
                indent: 16,
                endIndent: 16,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: SignInSuccessScreen._textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: SignInSuccessScreen._textDark,
          ),
        ),
      ],
    );
  }
}
