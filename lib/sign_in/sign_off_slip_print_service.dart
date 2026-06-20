import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import '../models/pos_signin_dto.dart';
import '../services/auth_session.dart';

/// SUNMI 80mm thermal output for a POS shift sign-off slip.
class SignOffSlipPrintService {
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm a');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy HH:mm');

  static const _rowWidth = 12;

  static String fmt(double value) => _money.format(value);
  static String fmtDate(DateTime dt) => _dateFmt.format(dt.toLocal());
  static String fmtTime(DateTime dt) => _timeFmt.format(dt.toLocal());
  static String fmtDateTime(DateTime dt) => _dateTimeFmt.format(dt.toLocal());

  static Future<void> printSignOffSlip(PosSignInDto signOff) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError(
        'Built-in thermal printing requires a SUNMI Android device.',
      );
    }

    final printer = SunmiPrinterPlus();
    await printer.rebindPrinter();

    final signOutWhen = signOff.signoutDatetime?.toLocal() ?? DateTime.now();
    final signInWhen = signOff.signinDatetime?.toLocal();

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

    final org = (signOff.organizationName?.trim().isNotEmpty == true
            ? signOff.organizationName!.trim()
            : AuthSession.organization.trim())
        .toUpperCase();
    final outlet = signOff.locationName?.trim().isNotEmpty == true
        ? signOff.locationName!.trim()
        : AuthSession.outlet.trim();

    if (org.isNotEmpty) {
      await SunmiPrinter.printText(org, style: centerBold);
    }
    if (outlet.isNotEmpty) {
      await SunmiPrinter.printText(outlet, style: centerMedium);
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('POS SHIFT SIGN-OFF', style: centerBold);
    await SunmiPrinter.lineWrap(1);

    final signInNo = signOff.signinId != null
        ? 'Sign-in #${signOff.signinId}'
        : 'Sign-off slip';
    await SunmiPrinter.printText('$signInNo  ·  ${fmtDateTime(signOutWhen)}',
        style: centerSmall);

    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    final empName = signOff.employeeName?.trim().isNotEmpty == true
        ? signOff.employeeName!.trim()
        : (AuthSession.fullname?.trim().isNotEmpty == true
            ? AuthSession.fullname!.trim()
            : (AuthSession.username ?? '—'));
    final empId = signOff.employeeId ?? AuthSession.employeeId;
    final empDisplay = empId != null ? '$empName (#$empId)' : empName;
    await _row('Employee', empDisplay, body, bodyBold);

    final terminal = [signOff.terminalCode, signOff.terminalName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join('  —  ');
    await _row(
      'Terminal',
      terminal.isNotEmpty ? terminal : (AuthSession.terminalCode ?? '—'),
      body,
      bodyBold,
    );

    if (signOff.businessUnitName?.trim().isNotEmpty == true) {
      await _row(
        'Business unit',
        signOff.businessUnitName!.trim(),
        body,
        bodyBold,
      );
    }

    final store = [signOff.storeCode, signOff.storeName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join('  —  ');
    if (store.isNotEmpty) {
      await _row('Store', store, body, bodyBold);
    }

    if (signInWhen != null) {
      await _row('Sign-in time', fmtDateTime(signInWhen), body, bodyBold);
    }
    await _row('Sign-off time', fmtDateTime(signOutWhen), body, bodyBold);

    final orderCount = signOff.postedOrderCount ?? signOff.orderCount;
    final totalAmount = signOff.postedTotalAmount ?? signOff.totalAmount;
    if (orderCount != null || totalAmount != null) {
      await SunmiPrinter.lineWrap(1);
      await _dottedLine();
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Shift totals', style: bodyBold);
      await SunmiPrinter.lineWrap(1);
      if (orderCount != null) {
        await _row('Total orders', '$orderCount', body, bodyBold);
      }
      if (totalAmount != null) {
        await _row(
          'Total amount',
          '${fmt(totalAmount)} BDT',
          body,
          bodyBold,
        );
      }
    }

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.printText('Status: SIGNED OFF', style: centerBold);

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
        text: 'Printed: ${fmtDate(DateTime.now())}',
        width: _rowWidth ~/ 2,
        style: small,
      ),
      SunmiColumn(
        text: fmtTime(DateTime.now()),
        width: _rowWidth ~/ 2,
        style: small.copyWith(align: SunmiPrintAlign.RIGHT),
      ),
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
