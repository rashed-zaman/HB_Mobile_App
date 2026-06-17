import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import '../models/pos_settlement_dto.dart';
import '../services/auth_session.dart';

/// Handles formatting + SUNMI 80mm thermal output for a settlement slip.
class SettlementSlipPrintService {
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm a');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy HH:mm');

  static const _rowWidth = 12;

  static String fmt(double value) => _money.format(value);
  static String fmtDate(DateTime dt) => _dateFmt.format(dt.toLocal());
  static String fmtTime(DateTime dt) => _timeFmt.format(dt.toLocal());
  static String fmtDateTime(DateTime dt) => _dateTimeFmt.format(dt.toLocal());

  /// Prints the settlement slip to the SUNMI built-in 80mm thermal printer.
  static Future<void> printSettlementSlip(PosSettlementDto slip) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError(
        'Built-in thermal printing requires a SUNMI Android device.',
      );
    }

    final printer = SunmiPrinterPlus();
    await printer.rebindPrinter();

    final now = slip.createdDate?.toLocal() ?? DateTime.now();
    final breakdown = slip.paymentBreakdown;

    // ── text styles ──────────────────────────────────────────────────────────
    final centerBold = SunmiTextStyle(
      align: SunmiPrintAlign.CENTER,
      bold: true,
      fontSize: 26,
    );
    final centerMedium = SunmiTextStyle(
      align: SunmiPrintAlign.CENTER,
      fontSize: 22,
    );
    final centerSmall = SunmiTextStyle(
      align: SunmiPrintAlign.CENTER,
      fontSize: 20,
    );
    final body = SunmiTextStyle(fontSize: 22);
    final bodyBold = SunmiTextStyle(fontSize: 22, bold: true);
    final small = SunmiTextStyle(fontSize: 20);
    final smallBold = SunmiTextStyle(fontSize: 20, bold: true);
    final tinyBold = SunmiTextStyle(fontSize: 18, bold: true);

    // ── header ───────────────────────────────────────────────────────────────
    final org = AuthSession.organization.trim();
    final outlet = AuthSession.outlet.trim();

    if (org.isNotEmpty) {
      await SunmiPrinter.printText(org.toUpperCase(), style: centerBold);
    }
    if (outlet.isNotEmpty) {
      await SunmiPrinter.printText(outlet, style: centerMedium);
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('POS SETTLEMENT SLIP', style: centerBold);
    await SunmiPrinter.lineWrap(1);

    // settlement # and date
    final settlementNo = 'Settlement #${slip.settlementId}';
    final dateStr = fmtDateTime(now);
    await SunmiPrinter.printText('$settlementNo  ·  $dateStr',
        style: centerSmall);

    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    // ── shift info ───────────────────────────────────────────────────────────
    final terminal = [slip.terminalCode, slip.terminalName]
        .where((s) => s != null && s.isNotEmpty)
        .join('  —  ');
    await _row('Terminal', terminal.isNotEmpty ? terminal : '—', body, bodyBold);

    final empName = slip.employeeName ?? '';
    final empCode = slip.employeeCode != null ? ' (${slip.employeeCode})' : '';
    await _row('Employee', '$empName$empCode', body, bodyBold);

    if (slip.signinDatetime != null) {
      await _row(
          'Shift sign-in', fmtDateTime(slip.signinDatetime!), body, bodyBold);
    }

    await SunmiPrinter.lineWrap(1);

    // ── totals ───────────────────────────────────────────────────────────────
    await _row('Total invoices',
        '${slip.totalInvoice ?? 0}', body, bodyBold);
    await SunmiPrinter.lineWrap(1);
    await _totalRow(
        'Total amount',
        '${fmt(slip.totalInvoiceAmount ?? 0)} BDT',
        bodyBold,
        bodyBold);

    if (slip.acceptedChangeMoneyAmount != null) {
      await _totalRow(
          'Accepted change money',
          '${fmt(slip.acceptedChangeMoneyAmount!)} BDT',
          small,
          small);
    }

    // ── payment breakdown ─────────────────────────────────────────────────────
    if (breakdown.lines.isNotEmpty) {
      await SunmiPrinter.lineWrap(1);
      await _dottedLine();
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Payment breakdown', style: tinyBold);
      await SunmiPrinter.lineWrap(1);

      // header row
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
            text: 'Method / Provider',
            width: 7,
            style: smallBold),
        SunmiColumn(
            text: 'Amount (BDT)',
            width: 5,
            style: smallBold.copyWith(align: SunmiPrintAlign.RIGHT)),
      ]);

      for (final line in breakdown.lines) {
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(text: line.displayLabel, width: 7, style: small),
          SunmiColumn(
              text: fmt(line.amount),
              width: 5,
              style: small.copyWith(align: SunmiPrintAlign.RIGHT)),
        ]);
      }

      await SunmiPrinter.lineWrap(1);
      await _dottedLine();
      await SunmiPrinter.lineWrap(1);
      await _totalRow(
          'Grand total',
          '${fmt(breakdown.grandTotal)} BDT',
          bodyBold,
          bodyBold);
    }

    // ── status footer ─────────────────────────────────────────────────────────
    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    final status = (slip.settlementAccepted == true) ? 'ACCEPTED' : 'PENDING';
    await SunmiPrinter.printText('Status: $status', style: centerBold);

    final cashier = AuthSession.fullname?.trim().isNotEmpty == true
        ? AuthSession.fullname!.trim()
        : (AuthSession.username ?? '');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
          text: 'Cashier: $cashier',
          width: _rowWidth ~/ 2,
          style: small),
      SunmiColumn(
          text: 'Date: ${fmtDate(now)}',
          width: _rowWidth ~/ 2,
          style: small.copyWith(align: SunmiPrintAlign.RIGHT)),
    ]);
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
          text: slip.locationName ?? '',
          width: _rowWidth ~/ 2,
          style: small),
      SunmiColumn(
          text: 'Time: ${fmtTime(now)}',
          width: _rowWidth ~/ 2,
          style: small.copyWith(align: SunmiPrintAlign.RIGHT)),
    ]);

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }

  static Future<void> _dottedLine() async {
    await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
  }

  static Future<void> _row(
    String label,
    String value,
    SunmiTextStyle labelStyle,
    SunmiTextStyle valueStyle,
  ) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: label, width: 4, style: labelStyle),
      SunmiColumn(text: value, width: 8, style: valueStyle),
    ]);
  }

  static Future<void> _totalRow(
    String label,
    String value,
    SunmiTextStyle labelStyle,
    SunmiTextStyle valueStyle,
  ) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: label, width: 7, style: labelStyle),
      SunmiColumn(
          text: value,
          width: 5,
          style: valueStyle.copyWith(align: SunmiPrintAlign.RIGHT)),
    ]);
  }
}

extension _StyleCopy on SunmiTextStyle {
  SunmiTextStyle copyWith({
    SunmiPrintAlign? align,
    bool? bold,
    int? fontSize,
  }) {
    return SunmiTextStyle(
      align: align ?? this.align ?? SunmiPrintAlign.LEFT,
      bold: bold ?? this.bold ?? false,
      fontSize: fontSize ?? this.fontSize ?? 22,
    );
  }
}
