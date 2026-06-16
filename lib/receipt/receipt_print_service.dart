import 'package:intl/intl.dart';

import '../models/pos_bill_response.dart';
import '../services/auth_session.dart';
import '../services/express_billing_service.dart';
import 'sunmi_thermal_printer.dart';

/// Store / org lines shown at top of thermal receipt.
class ReceiptStoreHeader {
  const ReceiptStoreHeader({
    required this.businessName,
    required this.address,
    required this.email,
    required this.phone,
  });

  final String businessName;
  final String address;
  final String email;
  final String phone;

  static ReceiptStoreHeader fromSession({PosBillResponse? bill}) {
    final mapping = AuthSession.defaultOrgMapping;
    final org = AuthSession.organization.trim();
    final outlet = AuthSession.outlet.trim();
    final store = bill?.storeName.trim().isNotEmpty == true
        ? bill!.storeName.trim()
        : AuthSession.store.trim();

    return ReceiptStoreHeader(
      businessName: org.isNotEmpty
          ? org.toUpperCase()
          : (store.isNotEmpty ? store.toUpperCase() : 'STORE'),
      address: outlet.isNotEmpty
          ? outlet
          : (mapping?.locationName ?? ''),
      email: AuthSession.email?.trim().isNotEmpty == true
          ? 'Email: ${AuthSession.email!.trim()}'
          : 'Email: —',
      phone: 'Tel: —',
    );
  }
}

class ReceiptPrintContext {
  const ReceiptPrintContext({
    required this.bill,
    required this.store,
    required this.terminalCode,
    required this.cashierName,
    required this.employeeId,
    this.printedAt,
  });

  final PosBillResponse bill;
  final ReceiptStoreHeader store;
  final String terminalCode;
  final String cashierName;
  final int? employeeId;
  final DateTime? printedAt;

  static Future<ReceiptPrintContext> fromBill(PosBillResponse bill) async {
    final terminal = await resolvePosTerminalCode();
    return ReceiptPrintContext(
      bill: bill,
      store: ReceiptStoreHeader.fromSession(bill: bill),
      terminalCode: terminal ?? '—',
      cashierName: AuthSession.fullname?.trim().isNotEmpty == true
          ? AuthSession.fullname!.trim()
          : (AuthSession.username ?? 'Cashier'),
      employeeId: AuthSession.employeeId,
      printedAt: DateTime.now(),
    );
  }
}

class ReceiptPaymentLineText {
  const ReceiptPaymentLineText({
    required this.label,
    required this.amount,
    this.indent = 0,
  });

  final String label;
  final String amount;
  final double indent;
}

class ReceiptPrintService {
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm a');

  static const termsText =
      '1. Goods once sold are not returnable unless defective.\n'
      '2. Please check items before leaving the counter.\n'
      '3. Keep this receipt for warranty & exchange.';

  static String formatMoney(double value) => '৳${_money.format(value)}';

  static String formatMoneyPlain(double value) => _money.format(value);

  static String formatDate(DateTime when) => _dateFmt.format(when);

  static String formatTime(DateTime when) => _timeFmt.format(when);

  static String billTypeLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'EXPRESS':
        return 'Express Sale';
      case 'B2B':
        return 'B2B Sale';
      case 'B2C':
        return 'B2C Sale';
      default:
        return raw.isNotEmpty ? raw : 'Sale';
    }
  }

  /// Prints directly to SUNMI built-in 80mm thermal printer (no system dialog).
  static Future<void> printThermalReceipt(ReceiptPrintContext ctx) async {
    await SunmiThermalPrinter.printReceipt(ctx);
  }

  static List<ReceiptPaymentLineText> paymentLineTexts(
    List<PosBillPaymentLine> payments,
  ) {
    final byMethod = <String, List<PosBillPaymentLine>>{};
    for (final p in payments) {
      byMethod.putIfAbsent(p.paymentMethod, () => []).add(p);
    }

    final lines = <ReceiptPaymentLineText>[];
    void addPaidLine(String label, double amount, {double indent = 0}) {
      lines.add(
        ReceiptPaymentLineText(
          label: label,
          amount: formatMoneyPlain(amount),
          indent: indent,
        ),
      );
    }

    for (final entry in byMethod.entries) {
      final method = entry.key;
      final methodLines = entry.value;
      final total = methodLines.fold(0.0, (s, e) => s + e.amount);
      switch (method) {
        case 'CASH':
          addPaidLine('Paid by Cash', total);
        case 'MFS':
          addPaidLine('Paid by MFS', total);
          for (final line in methodLines) {
            final name = line.providerName?.trim();
            if (name != null && name.isNotEmpty) {
              addPaidLine('-$name', line.amount, indent: 12);
            }
          }
        case 'CARD':
          addPaidLine('Paid by Card', total);
          for (final line in methodLines) {
            final name = line.providerName?.trim();
            if (name != null && name.isNotEmpty) {
              addPaidLine('-$name', line.amount, indent: 12);
            }
          }
        case 'BANK':
          addPaidLine('Paid by Bank', total);
        default:
          addPaidLine('Paid by $method', total);
      }
    }
    return lines;
  }

  static String qtyLabel(double qty) {
    if (qty % 1 == 0) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(2);
  }
}
