import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

String formatAmount(num value, {bool keepTwoDecimals = false}) {
  final isWhole = value % 1 == 0;
  final raw = keepTwoDecimals || !isWhole
      ? value.toStringAsFixed(2)
      : value.toStringAsFixed(0);
  final parts = raw.split('.');
  var intPart = parts.first;
  final sign = intPart.startsWith('-') ? '-' : '';
  if (sign.isNotEmpty) intPart = intPart.substring(1);

  if (intPart.length > 3) {
    final last3 = intPart.substring(intPart.length - 3);
    var lead = intPart.substring(0, intPart.length - 3);
    final groups = <String>[];
    while (lead.length > 2) {
      groups.insert(0, lead.substring(lead.length - 2));
      lead = lead.substring(0, lead.length - 2);
    }
    if (lead.isNotEmpty) groups.insert(0, lead);
    intPart = '${groups.join(',')},$last3';
  }

  return sign +
      intPart +
      ((parts.length > 1 && (keepTwoDecimals || !isWhole))
          ? '.${parts[1]}'
          : '');
}

double? parseMoneyInput(String raw) {
  final s = raw.replaceAll(',', '').replaceAll('৳', '').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Push this screen after the loading animation completes.
///
/// ```dart
/// Navigator.of(context).pushReplacement(
///   MaterialPageRoute(
///     builder: (_) => PaymentScreen(
///       invoiceNumber: 'INV-20250512-3464',
///       itemCount: 4,
///       totalBill: 42700,
///       onPrintReceipt: () { /* clear cart, pop */ },
///     ),
///   ),
/// );
/// ```
class PaymentScreen extends StatefulWidget {
  final String invoiceNumber;
  final int itemCount;
  final double totalBill;
  final VoidCallback onPrintReceipt;

  const PaymentScreen({
    super.key,
    required this.invoiceNumber,
    required this.itemCount,
    required this.totalBill,
    required this.onPrintReceipt,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Which payment method row is currently selected (null = none tapped yet)
  int? _selectedMethod;

  /// Discount total (hook up when "Add discount" is implemented).
  double _discountTotal = 0;

  late double _receivedAmount;

  double get _netPayable =>
      (widget.totalBill - _discountTotal).clamp(0.0, double.infinity);

  /// Cash/customer paid − net payable. Negative means shortfall.
  double get _changeAmount => _receivedAmount - _netPayable;

  @override
  void initState() {
    super.initState();
    _receivedAmount = _netPayable;
  }

  Future<void> _editReceivedAmount() async {
    final controller = TextEditingController(
      text: _receivedAmount.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Received amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          decoration: const InputDecoration(
            hintText: 'Enter amount',
            prefixText: '৳ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = parseMoneyInput(controller.text);
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _receivedAmount = result);
    }
  }

  // Formatted invoice label  e.g. "INV-20250512-3464" → "#3464"
  String get _invoiceLabel {
    final parts = widget.invoiceNumber.split('-');
    return '#${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          _TopBar(invoiceLabel: _invoiceLabel),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bill summary ──────────────────────────────────────────
                  _AmountRow(
                    label: 'Total Bill (${widget.itemCount} Items)',
                    amount: widget.totalBill,
                  ),

                  // ── Add discount ──────────────────────────────────────────
                  const _DiscountButton(),

                  // ── Net payable ───────────────────────────────────────────
                  _AmountRow(
                    label: 'Net Payable',
                    amount: _netPayable,
                    large: true,
                  ),

                  const _Divider(),

                  // ── Payment methods ───────────────────────────────────────
                  const _SectionTitle('Add a payment method'),

                  _PaymentMethodRow(
                    index: 0,
                    leading: _CashLogo(),
                    title: 'Cash',
                    selected: _selectedMethod == 0,
                    onTap: () => setState(() => _selectedMethod = 0),
                  ),
                  _PaymentMethodRow(
                    index: 1,
                    leading: _MfsLogo(),
                    title: 'MFS',
                    selected: _selectedMethod == 1,
                    onTap: () => setState(() => _selectedMethod = 1),
                  ),
                  _PaymentMethodRow(
                    index: 2,
                    leading: _CreditCardsLogo(),
                    title: 'Credit or debit card',
                    selected: _selectedMethod == 2,
                    onTap: () => setState(() => _selectedMethod = 2),
                  ),
                  _PaymentMethodRow(
                    index: 3,
                    leading: _BanglaQrLogo(),
                    title: 'Bangla QR',
                    selected: _selectedMethod == 3,
                    onTap: () => setState(() => _selectedMethod = 3),
                    isLast: true,
                  ),

                  const SizedBox(height: 6),

                  // ── Received amount (tap to edit) ─────────────────────────
                  _AmountRow(
                    label: 'Received Amount',
                    amount: _receivedAmount,
                    large: true,
                    onTap: _editReceivedAmount,
                    trailing: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  // ── Change / balance ─────────────────────────────────────
                  _ChangeChip(change: _changeAmount),

                  const _Divider(),

                  const SizedBox(height: 80), // breathing room above bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Print receipt bar ─────────────────────────────────────────────────
      bottomSheet: _PrintBar(onPrint: widget.onPrintReceipt),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String invoiceLabel;
  const _TopBar({required this.invoiceLabel});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0C0A10), Color(0xFF132746), Color(0xFF1C2439)],
        ),
      ),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'Invoice no: $invoiceLabel',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            Positioned(
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount Row
// ─────────────────────────────────────────────────────────────────────────────

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool large;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AmountRow({
    required this.label,
    required this.amount,
    this.large = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: large ? 15 : 14,
                fontWeight: large ? FontWeight.w600 : FontWeight.w400,
                color: const Color(0xFF232730),
              ),
            ),
          ),
          Text(
            '৳ ${formatAmount(amount, keepTwoDecimals: true)}',
            style: TextStyle(
              fontSize: large ? 22 : 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1117),
              letterSpacing: -0.5,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      );
    }
    return row;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discount Button
// ─────────────────────────────────────────────────────────────────────────────

class _DiscountButton extends StatelessWidget {
  const _DiscountButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.local_activity_outlined, size: 20),
        label: const Text(
          'Add discount',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: const Color(0xFF121317),
          side: const BorderSide(color: Color(0xFF41434A), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1F2E),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Method Row
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodRow extends StatelessWidget {
  final int index;
  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  const _PaymentMethodRow({
    required this.index,
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F4FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
              bottom: isLast
                  ? const BorderSide(color: Color(0xFFE5E7EB), width: 0.8)
                  : BorderSide.none,
              left: selected
                  ? const BorderSide(color: Color(0xFF1A1A2E), width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 72, child: leading),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF0D1117)
                        : const Color(0xFF1C2230),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFADB5BD),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeChip extends StatelessWidget {
  /// Positive = change to return; negative = amount still owed.
  final double change;
  const _ChangeChip({required this.change});

  @override
  Widget build(BuildContext context) {
    final shortfall = change < -0.009;
    final displayValue = change.abs();
    final label = shortfall ? 'Balance Due:' : 'Change Amount:';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: shortfall
            ? const Color(0xFFFFE4E4)
            : const Color(0xFFDCECE6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: shortfall
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFF1F3C34),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '৳ ${formatAmount(displayValue, keepTwoDecimals: true)}',
            style: TextStyle(
              fontSize: 17,
              color: shortfall
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Divider
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFDCDDDF));
}

// ─────────────────────────────────────────────────────────────────────────────
// Print Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PrintBar extends StatelessWidget {
  final VoidCallback onPrint;
  const _PrintBar({required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined, size: 20),
              label: const Text(
                'Print receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method logo widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Cash payment icon from assets/images/cash.png
class _CashLogo extends StatelessWidget {
  static const String _assetPath = 'assets/images/cash.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFD1FAE5),
            alignment: Alignment.center,
            child: const Icon(Icons.payments_rounded, color: Color(0xFF22C55E), size: 22),
          ),
        ),
      ),
    );
  }
}

/// MFS payment icon from assets/images/mfs.png
class _MfsLogo extends StatelessWidget {
  static const String _assetPath = 'assets/images/mfs.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFEFF6FF),
            alignment: Alignment.center,
            child: const Icon(Icons.phone_android_rounded, color: Color(0xFF2563EB), size: 22),
          ),
        ),
      ),
    );
  }
}

/// Credit / debit card networks icon from assets/images/credit-cards.png
class _CreditCardsLogo extends StatelessWidget {
  static const String _assetPath = 'assets/images/credit-cards.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFEAF0FF),
            alignment: Alignment.center,
            child: const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 22),
          ),
        ),
      ),
    );
  }
}

/// Bangla QR icon from assets/images/bangla-qr.png
class _BanglaQrLogo extends StatelessWidget {
  static const String _assetPath = 'assets/images/bangla-qr.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFEAF9EF),
            alignment: Alignment.center,
            child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF16A34A), size: 22),
          ),
        ),
      ),
    );
  }
}