import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import 'receipt_print_service.dart';

/// Direct 80mm (3-inch) thermal print on SUNMI built-in printer — no system dialog.
class SunmiThermalPrinter {
  static const _rowWidth = 12;

  static Future<void> printReceipt(ReceiptPrintContext ctx) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError(
        'Built-in thermal printing requires a SUNMI Android device.',
      );
    }

    final printer = SunmiPrinterPlus();
    await printer.rebindPrinter();

    final bill = ctx.bill;
    final summary = bill.summary;
    final when = ctx.printedAt ?? DateTime.now();
    final barcodeData =
        bill.billNumber.isNotEmpty ? bill.billNumber : '${bill.id ?? ''}';

    final centerBold = SunmiTextStyle(
      align: SunmiPrintAlign.CENTER,
      bold: true,
      fontSize: 28,
    );
    final center = SunmiTextStyle(
      align: SunmiPrintAlign.CENTER,
      fontSize: 22,
    );
    final body = SunmiTextStyle(fontSize: 22);
    final bodyBold = SunmiTextStyle(fontSize: 22, bold: true);
    final small = SunmiTextStyle(fontSize: 20);
    final smallBold = SunmiTextStyle(fontSize: 20, bold: true);

    await SunmiPrinter.printText('LOGO', style: centerBold);
    await SunmiPrinter.printText(ctx.store.businessName, style: centerBold);
    if (ctx.store.address.isNotEmpty) {
      await SunmiPrinter.printText(ctx.store.address, style: center);
    }
    await SunmiPrinter.printText(ctx.store.email, style: center);
    await SunmiPrinter.printText(ctx.store.phone, style: center);

    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await _labelValue('SR Type:', ReceiptPrintService.billTypeLabel(bill.billType), body, bodyBold);
    await _labelValue('SR No:', bill.billNumber, body, bodyBold);
    await _labelValue('Customer:', bill.customerName, body, bodyBold);
    await _labelValue('Phone:', bill.phoneNo, body, bodyBold);
    await _labelValue(
      'Date & time:',
      '${ReceiptPrintService.formatDate(when)} - ${ReceiptPrintService.formatTime(when)}',
      body,
      bodyBold,
    );

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(text: 'Item Name', width: 5, style: smallBold),
        SunmiColumn(
          text: 'Unit Price',
          width: 3,
          style: smallBold.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
        SunmiColumn(
          text: 'Qty',
          width: 1,
          style: smallBold.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
        SunmiColumn(
          text: 'Total',
          width: 3,
          style: smallBold.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    for (final item in bill.items) {
      final lineTotal =
          item.subtotal > 0 ? item.subtotal : item.quantity * item.rate;
      await SunmiPrinter.printRow(
        cols: [
          SunmiColumn(text: item.itemName, width: 5, style: small),
          SunmiColumn(
            text: ReceiptPrintService.formatMoneyPlain(item.rate),
            width: 3,
            style: small.copyWith(align: SunmiPrintAlign.RIGHT),
          ),
          SunmiColumn(
            text: ReceiptPrintService.qtyLabel(item.quantity),
            width: 1,
            style: small.copyWith(align: SunmiPrintAlign.RIGHT),
          ),
          SunmiColumn(
            text: ReceiptPrintService.formatMoneyPlain(lineTotal),
            width: 3,
            style: small.copyWith(align: SunmiPrintAlign.RIGHT),
          ),
        ],
      );
    }

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await _totalRow('Subtotal', ReceiptPrintService.formatMoneyPlain(summary.totalAmount), small, smallBold);
    if (summary.discountAmount > 0) {
      await _totalRow(
        '(-) Discount',
        ReceiptPrintService.formatMoneyPlain(summary.discountAmount),
        small,
        smallBold,
      );
    }
    await _totalRow(
      'Net Payable',
      ReceiptPrintService.formatMoneyPlain(summary.netPayable),
      smallBold,
      smallBold,
    );

    await SunmiPrinter.lineWrap(1);
    for (final line in ReceiptPrintService.paymentLineTexts(bill.payments)) {
      await _totalRow(line.label, line.amount, small, small);
    }

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await _totalRow(
      'Total Received',
      ReceiptPrintService.formatMoneyPlain(summary.totalPaid),
      smallBold,
      smallBold,
    );
    if (summary.changeGiven > 0) {
      await _totalRow(
        'Change Given',
        ReceiptPrintService.formatMoneyPlain(summary.changeGiven),
        smallBold,
        smallBold,
      );
    }

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.printText('Terms and condition:', style: smallBold);
    await SunmiPrinter.printText(ReceiptPrintService.termsText, style: small);

    await SunmiPrinter.lineWrap(1);
    await _dottedLine();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'Terminal: ${ctx.terminalCode}',
          width: _rowWidth ~/ 2,
          style: small,
        ),
        SunmiColumn(
          text: 'Date : ${ReceiptPrintService.formatDate(when)}',
          width: _rowWidth ~/ 2,
          style: small.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text:
              'Cashier : ${ctx.cashierName}${ctx.employeeId != null ? ' (#${ctx.employeeId})' : ''}',
          width: _rowWidth ~/ 2,
          style: small,
        ),
        SunmiColumn(
          text: 'Time : ${ReceiptPrintService.formatTime(when)}',
          width: _rowWidth ~/ 2,
          style: small.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    if (barcodeData.isNotEmpty) {
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.printBarCode(
        barcodeData,
        style: SunmiBarcodeStyle(
          type: SunmiBarcodeType.CODE128,
          align: SunmiPrintAlign.CENTER,
          height: 90,
          textPos: SunmiBarcodeTextPos.NO_TEXT,
        ),
      );
    }

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }

  static Future<void> _dottedLine() async {
    await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
  }

  static Future<void> _labelValue(
    String label,
    String value,
    SunmiTextStyle valueStyle,
    SunmiTextStyle labelStyle,
  ) async {
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(text: label, width: 4, style: labelStyle),
        SunmiColumn(text: value, width: 8, style: valueStyle),
      ],
    );
  }

  static Future<void> _totalRow(
    String label,
    String value,
    SunmiTextStyle labelStyle,
    SunmiTextStyle valueStyle,
  ) async {
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(text: label, width: 7, style: labelStyle),
        SunmiColumn(
          text: value,
          width: 5,
          style: valueStyle.copyWith(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
  }
}

extension on SunmiTextStyle {
  SunmiTextStyle copyWith({
    SunmiPrintAlign? align,
    bool? bold,
    int? fontSize,
  }) {
    return SunmiTextStyle(
      align: align ?? this.align ?? SunmiPrintAlign.LEFT,
      bold: bold ?? this.bold ?? false,
      fontSize: fontSize ?? this.fontSize ?? 24,
    );
  }
}
