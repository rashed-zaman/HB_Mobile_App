import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';

/// Shows the Enter Quantity bottom-sheet and returns the chosen quantity,
/// or null if the user dismissed without adding.
///
/// Usage:
/// ```dart
/// final qty = await showQuantitySheet(context, product: product);
/// if (qty != null) { /* add to cart */ }
/// ```
Future<int?> showQuantitySheet(
  BuildContext context, {
  required Product product,
  int initialQuantity = 1,
  String actionText = 'Add item',
  String? detailsText,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (_) => _QuantitySheet(
      product: product,
      initialQuantity: initialQuantity,
      actionText: actionText,
      detailsText: detailsText,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _QuantitySheet extends StatefulWidget {
  final Product product;
  final int initialQuantity;
  final String actionText;
  final String? detailsText;
  const _QuantitySheet({
    required this.product,
    required this.initialQuantity,
    required this.actionText,
    this.detailsText,
  });

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late String _raw; // always non-empty

  @override
  void initState() {
    super.initState();
    final sanitized = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
    _raw = sanitized.toString();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  int get _qty => int.tryParse(_raw) ?? 0;

  bool get _enforceStockLimit => widget.product.stock > 0;

  String? get _stockValidationError {
    if (!_enforceStockLimit || _qty <= 0) return null;
    if (_qty > widget.product.stock) {
      return 'Quantity cannot be greater than available stock (${widget.product.stock} Pcs)';
    }
    return null;
  }

  void _append(String digit) {
    setState(() {
      if (_raw == '0') {
        _raw = digit;
      } else {
        final next = _raw + digit;
        // Guard against absurdly large numbers
        if (next.length <= 5) _raw = next;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_raw.length <= 1) {
        _raw = '0';
      } else {
        _raw = _raw.substring(0, _raw.length - 1);
      }
    });
  }

  void _increment() {
    final next = _qty + 1;
    if (_enforceStockLimit && next > widget.product.stock) return;
    if (next.toString().length <= 5) setState(() => _raw = next.toString());
  }

  void _decrement() {
    final next = _qty - 1;
    setState(() => _raw = next < 0 ? '0' : next.toString());
  }

  void _clear() => setState(() => _raw = '0');

  void _submit() {
    if (_qty <= 0 || _stockValidationError != null) return;
    Navigator.of(context).pop<int>(_qty);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7), // iOS-style light grey background
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildWhiteCard(
            child: Column(
              children: [
                _buildTitleRow(),
                const SizedBox(height: 16),
                _buildProductInfo(),
                const SizedBox(height: 20),
                _buildQuantityRow(),
                if (_stockValidationError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _stockValidationError!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildAddButton(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildNumpad(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCCCCCC),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: child,
    );
  }

  Widget _buildTitleRow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'Enter Quantity',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Color(0xFF666666)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    final p = widget.product;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.detailsText ?? 'Code: ${p.code}  |  Stock: ${p.stockLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '৳ ${_formatPrice(p.price)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityRow() {
    return Row(
      children: [
        // ── delete / clear button ──
        _CircleButton(
          onTap: _clear,
          child: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF555555)),
        ),
        const SizedBox(width: 12),

        // ── quantity display ──
        Expanded(
          child: GestureDetector(
            onTap: () {}, // tapping the field does nothing; numpad is always shown
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1A1A2E), width: 1.8),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _raw,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  // blinking cursor indicator
                  Container(
                    margin: const EdgeInsets.only(left: 2, top: 2),
                    width: 2,
                    height: 22,
                    color: const Color(0xFF1A1A2E),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── plus button ──
        _CircleButton(
          onTap: _increment,
          child: const Icon(Icons.add, size: 22, color: Color(0xFF555555)),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    final enabled = _qty > 0 && _stockValidationError == null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          disabledBackgroundColor: const Color(0xFFCCCCCC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          widget.actionText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ── numpad ─────────────────────────────────────────────────────────────────

  Widget _buildNumpad() {
    return Container(
      color: const Color(0xFFD1D5DB), // grid-line colour (shows between keys)
      child: Column(
        children: [
          _numRow(['1', '2', '3'], subs: ['', 'ABC', 'DEF']),
          _numRow(['4', '5', '6'], subs: ['GHI', 'JKL', 'MNO']),
          _numRow(['7', '8', '9'], subs: ['PQRS', 'TUV', 'WXYZ']),
          _numRow(['', '0', 'back'], subs: ['', '', '']),
        ],
      ),
    );
  }

  Widget _numRow(List<String> keys, {required List<String> subs}) {
    return Row(
      children: List.generate(3, (i) {
        final key = keys[i];
        final sub = i < subs.length ? subs[i] : '';
        return Expanded(
          child: _NumKey(
            label: key,
            sublabel: sub,
            onTap: () {
              HapticFeedback.lightImpact();
              if (key == 'back') {
                _backspace();
              } else if (key.isNotEmpty) {
                _append(key);
              }
            },
          ),
        );
      }),
    );
  }

  // ── utils ──────────────────────────────────────────────────────────────────

  String _formatPrice(double price) {
    if (price % 1 == 0) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _CircleButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 1.2),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _NumKey({
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  bool get _isBack => label == 'back';
  bool get _isEmpty => label.isEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isEmpty ? null : onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(0.5), // creates the grid-line effect
        color: _isEmpty ? const Color(0xFFD1D5DB) : Colors.white,
        alignment: Alignment.center,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isEmpty) return const SizedBox.shrink();

    if (_isBack) {
      return const Icon(
        Icons.backspace_outlined,
        size: 22,
        color: Color(0xFF1A1A2E),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1A1A2E),
            height: 1,
          ),
        ),
        if (sublabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888888),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}