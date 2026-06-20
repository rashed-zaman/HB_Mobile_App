import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pos_signin_dto.dart';
import '../services/auth_session.dart';

/// On-screen sign-in slip preview — matches [SignInSlipPrintService] layout.
class SignInPreviewWidget extends StatelessWidget {
  const SignInPreviewWidget({super.key, required this.signIn});

  final PosSignInDto signIn;

  static const _bg = Color(0xFFF3F4F6);
  static const _cardBg = Colors.white;
  static const _ink = Color(0xFF0D1117);
  static const _muted = Color(0xFF6B7280);
  static const _success = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _divider = Color(0xFFE5E7EB);

  static final _dtFmt = DateFormat('dd MMM yyyy  HH:mm');
  static final _money = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final when = signIn.signinDatetime?.toLocal() ?? DateTime.now();
    final org = signIn.organizationName?.trim().isNotEmpty == true
        ? signIn.organizationName!.trim()
        : AuthSession.organization.trim();
    final outlet = signIn.locationName?.trim().isNotEmpty == true
        ? signIn.locationName!.trim()
        : AuthSession.outlet.trim();

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _successBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _success.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '✓  Sign in successful',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _success,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  if (org.isNotEmpty)
                    Text(
                      org.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (outlet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      outlet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'POS SHIFT SIGN-IN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signIn.signinId != null
                        ? 'Sign-in #${signIn.signinId}  ·  ${_dtFmt.format(when)}'
                        : _dtFmt.format(when),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 12),
                  _row('Employee', _employeeDisplay()),
                  _row('Terminal', _terminalDisplay()),
                  if (signIn.businessUnitName?.trim().isNotEmpty == true)
                    _row('Business unit', signIn.businessUnitName!.trim()),
                  if (_storeDisplay().isNotEmpty) _row('Store', _storeDisplay()),
                  _row('Sign-in time', _dtFmt.format(when)),
                  if (signIn.orderCount != null || signIn.totalAmount != null) ...[
                    const SizedBox(height: 8),
                    const Divider(color: _divider, height: 1),
                    const SizedBox(height: 12),
                    if (signIn.orderCount != null)
                      _row('Open orders', '${signIn.orderCount}'),
                    if (signIn.totalAmount != null)
                      _row(
                        'Open amount',
                        '৳${_money.format(signIn.totalAmount)}',
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _employeeDisplay() {
    final name = signIn.employeeName?.trim().isNotEmpty == true
        ? signIn.employeeName!.trim()
        : (AuthSession.fullname?.trim().isNotEmpty == true
            ? AuthSession.fullname!.trim()
            : (AuthSession.username ?? '—'));
    final id = signIn.employeeId ?? AuthSession.employeeId;
    return id != null ? '$name (#$id)' : name;
  }

  String _terminalDisplay() {
    final parts = <String>[
      if (signIn.terminalCode?.trim().isNotEmpty == true)
        signIn.terminalCode!.trim(),
      if (signIn.terminalName?.trim().isNotEmpty == true)
        signIn.terminalName!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join('  —  ');
    return AuthSession.terminalCode ?? '—';
  }

  String _storeDisplay() {
    return [
      if (signIn.storeCode?.trim().isNotEmpty == true) signIn.storeCode!.trim(),
      if (signIn.storeName?.trim().isNotEmpty == true) signIn.storeName!.trim(),
    ].join('  —  ');
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
