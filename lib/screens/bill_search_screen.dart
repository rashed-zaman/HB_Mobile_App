import 'package:flutter/material.dart';

import '../models/pos_bill_response.dart';
import '../receipt/receipt_print_service.dart';
import '../services/auth_session.dart';
import '../services/express_billing_service.dart';
import 'invoice_preview_screen.dart';

class BillSearchScreen extends StatefulWidget {
  const BillSearchScreen({super.key});

  @override
  State<BillSearchScreen> createState() => _BillSearchScreenState();
}

class _BillSearchScreenState extends State<BillSearchScreen> {
  final _invoiceController = TextEditingController();
  final _billingService = ExpressBillingService();
  bool _isSearching = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    _billingService.close();
    super.dispose();
  }

  Future<void> _search() async {
    if (_isSearching) return;

    final invoiceNumber = _invoiceController.text.trim();
    if (invoiceNumber.isEmpty) {
      _showMessage('Enter an invoice number.', isError: true);
      return;
    }

    final employeeId = AuthSession.employeeId;
    if (employeeId == null || employeeId <= 0) {
      _showMessage('No employee linked to this session.', isError: true);
      return;
    }

    if (AuthSession.authorizationHeader == null) {
      _showMessage('Please sign in again.', isError: true);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await _billingService.searchBill(
        invoiceNumber: invoiceNumber,
        employeeId: employeeId,
      );

      if (!mounted) return;

      final bill = PosBillResponse.fromJson(result);
      final printContext = await ReceiptPrintContext.fromBill(bill);

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(
            bill: bill,
            printContext: printContext,
            autoPrint: false,
          ),
        ),
      );
    } on ExpressBillingException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          'Bill search',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Invoice number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _invoiceController,
                enabled: !_isSearching,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'e.g. POS-2026040000099',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D1117)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1117),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
