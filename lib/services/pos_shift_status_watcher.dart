import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_session.dart';
import 'pos_shift_service.dart';
import 'pos_sign_in_helper.dart';

/// Polls `/api/mobile/pos/signin/status` while a settlement is pending so the
/// handset learns when a manager accepts it on the web pending page.
class PosShiftStatusWatcher extends ChangeNotifier {
  PosShiftStatusWatcher._();

  static final PosShiftStatusWatcher instance = PosShiftStatusWatcher._();

  final PosShiftService _shiftService = PosShiftService();

  Timer? _pollTimer;
  PosShiftStatus? _status;
  bool _isRefreshing = false;
  bool _pendingAcceptanceNotification = false;

  PosShiftStatus? get status => _status;

  bool get isRefreshing => _isRefreshing;

  /// Returns true once per manager acceptance so only one UI surface shows a snackbar.
  bool consumeSettlementAcceptedNotification() {
    if (!_pendingAcceptanceNotification) return false;
    _pendingAcceptanceNotification = false;
    return true;
  }

  /// Applies a shift-status snapshot (e.g. from settlement submit) and starts
  /// polling when a settlement is pending manager approval.
  void applyStatus(PosShiftStatus status) {
    final wasPending = _status?.pendingSettlement == true;
    _status = status;
    AuthSession.applyShiftStatusFlags(
      pendingSettlement: status.pendingSettlement,
      settlementAccepted: status.settlementAccepted,
    );
    final nowPending = status.pendingSettlement;
    if (wasPending && !nowPending && status.settlementAccepted) {
      _pendingAcceptanceNotification = true;
    }
    _managePolling(nowPending);
    notifyListeners();
  }

  /// Refreshes shift status once. Returns `true` when settlement was just accepted.
  Future<bool> refresh({bool notify = true}) async {
    if (!AuthSession.deviceShiftOperationsEnabled) {
      _stopPolling();
      _status = null;
      if (notify) notifyListeners();
      return false;
    }

    final request = await resolvePosSignInRequest();
    final terminalCode = request.terminalCode?.trim();
    if (terminalCode == null || terminalCode.isEmpty) return false;

    final wasPending = _status?.pendingSettlement == true;
    _isRefreshing = true;
    if (notify) notifyListeners();

    try {
      final next =
          await _shiftService.getShiftStatus(terminalCode: terminalCode);

      final nowPending = next?.pendingSettlement == true;
      final accepted = next?.settlementAccepted == true;
      final justAccepted = wasPending && next != null && !nowPending && accepted;

      if (next != null) {
        AuthSession.applyShiftStatusFlags(
          pendingSettlement: next.pendingSettlement,
          settlementAccepted: next.settlementAccepted,
        );
      }

      _status = next;
      if (justAccepted) {
        _pendingAcceptanceNotification = true;
      }
      _managePolling(nowPending);
      return justAccepted;
    } finally {
      _isRefreshing = false;
      if (notify) notifyListeners();
    }
  }

  void _managePolling(bool pending) {
    if (!pending) {
      _stopPolling();
      return;
    }
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => refresh(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void disposeWatcher() {
    _stopPolling();
    _shiftService.close();
  }
}
