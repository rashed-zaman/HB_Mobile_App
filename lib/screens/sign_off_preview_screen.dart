import 'package:flutter/material.dart';

import '../models/pos_signin_dto.dart';
import '../sign_in/sign_off_preview_widget.dart';
import '../sign_in/sign_off_slip_print_service.dart';

/// Full-screen sign-off slip preview with auto-print + reprint button.
class SignOffPreviewScreen extends StatefulWidget {
  const SignOffPreviewScreen({
    super.key,
    required this.signOff,
    this.autoPrint = true,
  });

  final PosSignInDto signOff;
  final bool autoPrint;

  @override
  State<SignOffPreviewScreen> createState() => _SignOffPreviewScreenState();
}

class _SignOffPreviewScreenState extends State<SignOffPreviewScreen> {
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
      await SignOffSlipPrintService.printSignOffSlip(widget.signOff);
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
        title: Column(
          children: [
            const Text(
              'Sign off slip',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (widget.signOff.signinId != null)
              Text(
                '#${widget.signOff.signinId}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SignOffPreviewWidget(signOff: widget.signOff),
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
