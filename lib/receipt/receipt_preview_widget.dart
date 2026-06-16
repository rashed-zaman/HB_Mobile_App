import 'package:flutter/material.dart';

import '../models/pos_bill_response.dart';
import 'receipt_print_service.dart';

/// On-screen 80mm thermal receipt preview (full width, centered header).
class ReceiptPreviewWidget extends StatelessWidget {
  const ReceiptPreviewWidget({super.key, required this.context});

  final ReceiptPrintContext context;

  @override
  Widget build(BuildContext context) {
    final ctx = this.context;
    final bill = ctx.bill;
    final summary = bill.summary;
    final when = ctx.printedAt ?? DateTime.now();
    final barcodeData =
        bill.billNumber.isNotEmpty ? bill.billNumber : '${bill.id ?? ''}';

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'LOGO',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1117),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                ctx.store.businessName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1117),
                ),
              ),
            ),
            if (ctx.store.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  ctx.store.address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 2),
            Center(
              child: Text(
                ctx.store.email,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
            ),
            Center(
              child: Text(
                ctx.store.phone,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(height: 10),
            _dottedLine(),
            const SizedBox(height: 10),
            _infoRow('SR Type:', ReceiptPrintService.billTypeLabel(bill.billType)),
            _infoRow('SR No:', bill.billNumber),
            _infoRow('Customer:', bill.customerName),
            _infoRow('Phone:', bill.phoneNo),
            _infoRow(
              'Date & time:',
              '${ReceiptPrintService.formatDate(when)} - ${ReceiptPrintService.formatTime(when)}',
            ),
            const SizedBox(height: 10),
            _dottedLine(),
            const SizedBox(height: 10),
            _itemsHeader(),
            const SizedBox(height: 6),
            ...bill.items.map(_itemRow),
            const SizedBox(height: 8),
            _dottedLine(),
            const SizedBox(height: 10),
            _totalRow('Subtotal', ReceiptPrintService.formatMoneyPlain(summary.totalAmount)),
            if (summary.discountAmount > 0)
              _totalRow(
                '(-) Discount',
                ReceiptPrintService.formatMoneyPlain(summary.discountAmount),
              ),
            const SizedBox(height: 4),
            _totalRow(
              'Net Payable',
              ReceiptPrintService.formatMoneyPlain(summary.netPayable),
              bold: true,
            ),
            const SizedBox(height: 8),
            ...ReceiptPrintService.paymentLineTexts(bill.payments).map(
              (line) => _totalRow(line.label, line.amount, indent: line.indent),
            ),
            const SizedBox(height: 8),
            _dottedLine(),
            const SizedBox(height: 10),
            _totalRow(
              'Total Received',
              ReceiptPrintService.formatMoneyPlain(summary.totalPaid),
              bold: true,
            ),
            if (summary.changeGiven > 0)
              _totalRow(
                'Change Given',
                ReceiptPrintService.formatMoneyPlain(summary.changeGiven),
                bold: true,
              ),
            const SizedBox(height: 10),
            _dottedLine(),
            const SizedBox(height: 10),
            const Text(
              'Terms and condition:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1117),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ReceiptPrintService.termsText,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 10),
            _dottedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Terminal: ${ctx.terminalCode}',
                    style: _footerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date : ${ReceiptPrintService.formatDate(when)}',
                    textAlign: TextAlign.right,
                    style: _footerStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cashier : ${ctx.cashierName}'
                    '${ctx.employeeId != null ? ' (#${ctx.employeeId})' : ''}',
                    style: _footerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Time : ${ReceiptPrintService.formatTime(when)}',
                    textAlign: TextAlign.right,
                    style: _footerStyle,
                  ),
                ),
              ],
            ),
            if (barcodeData.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 180,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.barcode_reader,
                        size: 36,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      barcodeData,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _footerStyle = TextStyle(fontSize: 11, color: Color(0xFF374151));

  Widget _dottedLine() {
    return const Text(
      '................................................',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), height: 1),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF0D1117)),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _itemsHeader() {
    return const Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'Item Name',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Unit Price',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            'Qty',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Total',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _itemRow(PosBillLineItem item) {
    final lineTotal =
        item.subtotal > 0 ? item.subtotal : item.quantity * item.rate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(item.itemName, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ReceiptPrintService.formatMoneyPlain(item.rate),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              ReceiptPrintService.qtyLabel(item.quantity),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ReceiptPrintService.formatMoneyPlain(lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, double indent = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
