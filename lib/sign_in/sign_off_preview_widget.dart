import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pos_signin_dto.dart';
import '../services/auth_session.dart';

/// On-screen sign-off slip preview — matches [SignOffSlipPrintService] layout.
class SignOffPreviewWidget extends StatelessWidget {
  const SignOffPreviewWidget({super.key, required this.signOff});

  final PosSignInDto signOff;

  static const _bg = Color(0xFFF3F4F6);
  static const _cardBg = Colors.white;
  static const _ink = Color(0xFF0D1117);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFFE65100);
  static const _accentBg = Color(0xFFFFF3E0);
  static const _divider = Color(0xFFE5E7EB);

  static final _dtFmt = DateFormat('dd MMM yyyy  HH:mm');
  static final _money = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final signOutWhen = signOff.signoutDatetime?.toLocal() ?? DateTime.now();
    final signInWhen = signOff.signinDatetime?.toLocal();
    final org = signOff.organizationName?.trim().isNotEmpty == true
        ? signOff.organizationName!.trim()
        : AuthSession.organization.trim();
    final outlet = signOff.locationName?.trim().isNotEmpty == true
        ? signOff.locationName!.trim()
        : AuthSession.outlet.trim();

    final orderCount = signOff.postedOrderCount ?? signOff.orderCount;
    final totalAmount = signOff.postedTotalAmount ?? signOff.totalAmount;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _accentBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _accent.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '✓  Sign off successful',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _accent,
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
                    'POS SHIFT SIGN-OFF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signOff.signinId != null
                        ? 'Sign-in #${signOff.signinId}  ·  ${_dtFmt.format(signOutWhen)}'
                        : _dtFmt.format(signOutWhen),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 12),
                  _row('Employee', _employeeDisplay()),
                  _row('Terminal', _terminalDisplay()),
                  if (signOff.businessUnitName?.trim().isNotEmpty == true)
                    _row('Business unit', signOff.businessUnitName!.trim()),
                  if (_storeDisplay().isNotEmpty) _row('Store', _storeDisplay()),
                  if (signInWhen != null)
                    _row('Sign-in time', _dtFmt.format(signInWhen)),
                  _row('Sign-off time', _dtFmt.format(signOutWhen)),
                  if (orderCount != null || totalAmount != null) ...[
                    const SizedBox(height: 8),
                    const Divider(color: _divider, height: 1),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Shift totals',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (orderCount != null)
                      _row('Total orders', '$orderCount'),
                    if (totalAmount != null)
                      _row(
                        'Total amount',
                        '৳${_money.format(totalAmount)}',
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
    final name = signOff.employeeName?.trim().isNotEmpty == true
        ? signOff.employeeName!.trim()
        : (AuthSession.fullname?.trim().isNotEmpty == true
            ? AuthSession.fullname!.trim()
            : (AuthSession.username ?? '—'));
    final id = signOff.employeeId ?? AuthSession.employeeId;
    return id != null ? '$name (#$id)' : name;
  }

  String _terminalDisplay() {
    final parts = <String>[
      if (signOff.terminalCode?.trim().isNotEmpty == true)
        signOff.terminalCode!.trim(),
      if (signOff.terminalName?.trim().isNotEmpty == true)
        signOff.terminalName!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join('  —  ');
    return AuthSession.terminalCode ?? '—';
  }

  String _storeDisplay() {
    return [
      if (signOff.storeCode?.trim().isNotEmpty == true)
        signOff.storeCode!.trim(),
      if (signOff.storeName?.trim().isNotEmpty == true)
        signOff.storeName!.trim(),
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
