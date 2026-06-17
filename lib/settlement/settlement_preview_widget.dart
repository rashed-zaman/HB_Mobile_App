import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pos_settlement_dto.dart';
import '../services/auth_session.dart';

/// Modern on-screen settlement slip, styled like a paper receipt card.
/// Matches the printed output from [SettlementSlipPrintService].
class SettlementPreviewWidget extends StatelessWidget {
  const SettlementPreviewWidget({super.key, required this.slip});

  final PosSettlementDto slip;

  // ── colours ─────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF4F6FA);
  static const _cardBg = Colors.white;
  static const _ink = Color(0xFF0D1117);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1A56DB);
  static const _accentLight = Color(0xFFEBF5FF);
  static const _divider = Color(0xFFE5E7EB);
  static const _success = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _pending = Color(0xFFD97706);
  static const _pendingBg = Color(0xFFFFF7ED);

  // ── formatters ───────────────────────────────────────────────────────────────
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _dtFmt = DateFormat('dd MMM yyyy  HH:mm');
  static final _dFmt = DateFormat('dd MMM yyyy');
  static final _tFmt = DateFormat('hh:mm a');

  static String _fmt(double? v) => _money.format(v ?? 0);
  static String _fmtDt(DateTime? dt) =>
      dt == null ? '—' : _dtFmt.format(dt.toLocal());
  static String _fmtD(DateTime? dt) =>
      dt == null ? '—' : _dFmt.format(dt.toLocal());
  static String _fmtT(DateTime? dt) =>
      dt == null ? '—' : _tFmt.format(dt.toLocal());

  @override
  Widget build(BuildContext context) {
    final accepted = slip.settlementAccepted == true;
    final now = slip.createdDate;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            _buildTopBadge(accepted),
            const SizedBox(height: 12),
            _buildSlipCard(accepted, now),
          ],
        ),
      ),
    );
  }

  // ── top status badge ─────────────────────────────────────────────────────────
  Widget _buildTopBadge(bool accepted) {
    final color = accepted ? _success : _pending;
    final bgColor = accepted ? _successBg : _pendingBg;
    final label = accepted ? '✓  Settlement Accepted' : '⏳  Pending Approval';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── main slip card ───────────────────────────────────────────────────────────
  Widget _buildSlipCard(bool accepted, DateTime? now) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildSlipHeader(now),
          _buildBody(accepted, now),
          _buildJaggedEdge(),
        ],
      ),
    );
  }

  // ── receipt header (blue gradient) ─────────────────────────────────────────
  Widget _buildSlipHeader(DateTime? now) {
    final org = AuthSession.organization.trim();
    final outlet = AuthSession.outlet.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // logo placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          if (org.isNotEmpty)
            Text(
              org.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          if (outlet.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              outlet,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'POS SETTLEMENT SLIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Settlement #${slip.settlementId}  ·  ${_fmtDt(now)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── main body ────────────────────────────────────────────────────────────────
  Widget _buildBody(bool accepted, DateTime? now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          // ── shift info ──────────────────────────────────────────────────────
          _sectionLabel('Shift Details'),
          const SizedBox(height: 8),
          _infoTable([
            _rowData('Terminal', _buildTerminalValue()),
            _rowData('Employee', _buildEmployeeValue()),
            if (slip.signinDatetime != null)
              _rowData('Shift sign-in', _fmtDt(slip.signinDatetime)),
          ]),

          const SizedBox(height: 20),
          _dividerLine(),
          const SizedBox(height: 20),

          // ── sales summary ───────────────────────────────────────────────────
          _sectionLabel('Sales Summary'),
          const SizedBox(height: 8),
          _infoTable([
            _rowData('Total invoices',
                '${slip.totalInvoice ?? 0}',
                valueStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
          ]),
          const SizedBox(height: 12),

          // Total amount big display
          _totalAmountCard(slip.totalInvoiceAmount ?? 0),

          if (slip.acceptedChangeMoneyAmount != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              'Accepted change money',
              '${_fmt(slip.acceptedChangeMoneyAmount)}  BDT',
              muted: true,
            ),
          ],

          // ── payment breakdown ───────────────────────────────────────────────
          if (slip.paymentBreakdown.lines.isNotEmpty) ...[
            const SizedBox(height: 20),
            _dividerLine(),
            const SizedBox(height: 20),
            _buildPaymentBreakdown(),
          ],

          // ── grand total ─────────────────────────────────────────────────────
          const SizedBox(height: 20),
          _dividerLine(),
          const SizedBox(height: 16),
          _buildGrandTotal(),

          const SizedBox(height: 20),
          _dividerLine(),
          const SizedBox(height: 16),

          // ── footer ──────────────────────────────────────────────────────────
          _buildFooter(now),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── terminal / employee helpers ───────────────────────────────────────────────
  String _buildTerminalValue() {
    final parts = [slip.terminalCode, slip.terminalName]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join('  —  ') : '—';
  }

  String _buildEmployeeValue() {
    final name = slip.employeeName ?? '';
    final code =
        slip.employeeCode != null ? '(${slip.employeeCode})' : '';
    final combined = [name, code].where((s) => s.isNotEmpty).join(' ');
    return combined.isNotEmpty ? combined : '—';
  }

  // ── total amount big card ─────────────────────────────────────────────────────
  Widget _totalAmountCard(double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total amount',
            style: TextStyle(fontSize: 12, color: _accent),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(amount),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'BDT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── payment breakdown table ───────────────────────────────────────────────────
  Widget _buildPaymentBreakdown() {
    final breakdown = slip.paymentBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Payment Breakdown'),
        const SizedBox(height: 10),
        // column header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Method / Provider',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.5),
                ),
              ),
              Text(
                'Amount (BDT)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        Container(height: 1, color: _divider),
        const SizedBox(height: 4),
        ...breakdown.lines.map(_buildPaymentRow),

        // collected subtotal
        if (breakdown.totalCollected > 0) ...[
          const SizedBox(height: 4),
          Container(height: 1, color: _divider),
          const SizedBox(height: 8),
          _buildPaymentSummaryRow(
              'Collected', breakdown.totalCollected, bold: false),
        ],
        if (breakdown.totalCredit > 0)
          _buildPaymentSummaryRow(
              'Credit / due', breakdown.totalCredit, bold: false),
      ],
    );
  }

  Widget _buildPaymentRow(PosSettlementPaymentLine line) {
    final isCredit = line.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: isCredit ? _pending : _accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              line.displayLabel,
              style: TextStyle(
                fontSize: 13,
                color: isCredit ? _pending : _ink,
                fontWeight:
                    isCredit ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            _fmt(line.amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCredit ? _pending : _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryRow(String label, double amount,
      {bool bold = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _muted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            _fmt(amount),
            style: TextStyle(
              fontSize: 13,
              color: _ink,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── grand total row ───────────────────────────────────────────────────────────
  Widget _buildGrandTotal() {
    final total = slip.paymentBreakdown.grandTotal > 0
        ? slip.paymentBreakdown.grandTotal
        : slip.totalInvoiceAmount ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Grand total',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _fmt(total),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'BDT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────────
  Widget _buildFooter(DateTime? now) {
    final cashier = AuthSession.fullname?.trim().isNotEmpty == true
        ? AuthSession.fullname!.trim()
        : (AuthSession.username ?? '—');
    final loc = slip.locationName?.trim() ?? '';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _footerKv(
                  'Cashier', '$cashier${slip.employeeCode != null ? ' (#${slip.employeeCode})' : ''}'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _footerKv('Date', _fmtD(now), align: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (loc.isNotEmpty)
              Expanded(child: _footerKv('Location', loc)),
            const Spacer(),
            _footerKv('Time', _fmtT(now), align: TextAlign.right),
          ],
        ),
      ],
    );
  }

  Widget _footerKv(String label, String value,
      {TextAlign align = TextAlign.left}) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 1),
        Text(value,
            textAlign: align,
            style: const TextStyle(
                fontSize: 12,
                color: _ink,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── info helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoTable(List<_RowData> rows) {
    return Column(
      children:
          rows.map((r) => _infoRow(r.label, r.value, valueStyle: r.valueStyle)).toList(),
    );
  }

  Widget _infoRow(String label, String value,
      {bool muted = false, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted ? _muted : _ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() {
    return Container(height: 1, color: _divider);
  }

  // ── jagged bottom edge (receipt look) ─────────────────────────────────────────
  Widget _buildJaggedEdge() {
    return CustomPaint(
      size: const Size(double.infinity, 14),
      painter: _JaggedEdgePainter(),
    );
  }
}

// ── helper data class ─────────────────────────────────────────────────────────
class _RowData {
  const _RowData(this.label, this.value, {this.valueStyle});
  final String label;
  final String value;
  final TextStyle? valueStyle;
}

_RowData _rowData(String label, String value, {TextStyle? valueStyle}) =>
    _RowData(label, value, valueStyle: valueStyle);

// ── jagged edge painter ───────────────────────────────────────────────────────
class _JaggedEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF4F6FA);
    final path = Path();
    path.moveTo(0, 0);
    const step = 14.0;
    double x = 0;
    while (x < size.width) {
      path.lineTo(x + step / 2, size.height);
      path.lineTo(x + step, 0);
      x += step;
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_JaggedEdgePainter oldDelegate) => false;
}
