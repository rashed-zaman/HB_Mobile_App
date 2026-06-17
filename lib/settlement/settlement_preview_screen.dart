import 'package:flutter/material.dart';

import '../models/pos_settlement_dto.dart';
import 'settlement_preview_widget.dart';
import 'settlement_slip_print_service.dart';

/// Full-screen settlement slip preview with auto-print + reprint button.
/// Opens automatically after a successful settlement submit.
class SettlementPreviewScreen extends StatefulWidget {
  const SettlementPreviewScreen({
    super.key,
    required this.slip,
    this.autoPrint = true,
  });

  final PosSettlementDto slip;
  final bool autoPrint;

  @override
  State<SettlementPreviewScreen> createState() =>
      _SettlementPreviewScreenState();
}

class _SettlementPreviewScreenState extends State<SettlementPreviewScreen> {
  bool _isPrinting = false;
  bool _didAutoPrint = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _print());
    }
  }

  Future<void> _print() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
      _printError = null;
    });
    try {
      await SettlementSlipPrintService.printSettlementSlip(widget.slip);
      if (mounted) {
        setState(() {
          _didAutoPrint = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: SettlementPreviewWidget(slip: widget.slip)),
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Color(0xFF0D1117)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          const Text(
            'Settlement Slip',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1117),
            ),
          ),
          Text(
            '#${widget.slip.settlementId}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (_printError != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 22),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isPrinting ? null : _print,
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_rounded, size: 20),
            label: Text(
              _isPrinting
                  ? 'Printing…'
                  : (_didAutoPrint ? 'Reprint Slip' : 'Print Slip'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
