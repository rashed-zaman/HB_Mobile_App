import 'package:flutter/material.dart';

import '../models/pos_bill_response.dart';
import '../receipt/receipt_preview_widget.dart';
import '../receipt/receipt_print_service.dart';

/// 80mm thermal receipt preview after save-print API success.
/// Prints directly to SUNMI built-in printer — no system print dialog.
class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.bill,
    required this.printContext,
    this.autoPrint = true,
    this.allowNewBill = false,
  });

  final PosBillResponse bill;
  final ReceiptPrintContext printContext;
  final bool autoPrint;

  /// When true (after checkout submit), hides back navigation and shows
  /// a [New Bill] action that returns to the POS home screen.
  final bool allowNewBill;

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _isPrinting = false;
  bool _didAutoPrint = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reprint());
    }
  }

  void _startNewBill() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _reprint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await ReceiptPrintService.printThermalReceipt(widget.printContext);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _didAutoPrint = true;
        });
      }
    }
  }

  Widget _buildPrintButton({required bool expanded}) {
    final button = ElevatedButton.icon(
      onPressed: _isPrinting ? null : _reprint,
      icon: _isPrinting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.print_outlined, size: 20),
      label: Text(
        _isPrinting
            ? 'Printing…'
            : (_didAutoPrint ? 'Reprint' : 'Print'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, height: 52, child: button);
    }
    return SizedBox(height: 52, child: button);
  }

  Widget _buildNewBillButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _startNewBill,
        icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
        label: const Text(
          'New Bill',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1117),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.allowNewBill,
        title: const Text(
          'Invoice Preview',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ReceiptPreviewWidget(context: widget.printContext),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: widget.allowNewBill
                  ? Row(
                      children: [
                        Expanded(child: _buildPrintButton(expanded: false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildNewBillButton()),
                      ],
                    )
                  : _buildPrintButton(expanded: true),
            ),
          ),
        ],
      ),
    );

    if (!widget.allowNewBill) return scaffold;

    return PopScope(
      canPop: false,
      child: scaffold,
    );
  }
}
