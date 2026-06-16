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
  });

  final PosBillResponse bill;
  final ReceiptPrintContext printContext;
  final bool autoPrint;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1117),
        elevation: 0,
        centerTitle: true,
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
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
