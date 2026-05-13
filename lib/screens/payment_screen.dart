import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
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

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a confirmed payment entry
// ─────────────────────────────────────────────────────────────────────────────

enum _PaymentType { cash, mfs, card }

class _PaymentEntry {
  final _PaymentType type;
  final double amount;

  /// For MFS: provider name ("bKash", "Nagad", "Upay"); for card: last-4 digits
  final String? detail;

  const _PaymentEntry({required this.type, required this.amount, this.detail});

  String get label {
    switch (type) {
      case _PaymentType.cash:
        return 'Cash';
      case _PaymentType.mfs:
        return detail ?? 'MFS';
      case _PaymentType.card:
        return 'Mastercard'; // you can derive from detail
    }
  }

  Widget get logo {
    switch (type) {
      case _PaymentType.cash:
        return _CashLogo();
      case _PaymentType.mfs:
        return _MfsProviderIcon(provider: detail ?? '');
      case _PaymentType.card:
        return _CardIcon(lastFour: detail ?? '');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PaymentScreen
// ─────────────────────────────────────────────────────────────────────────────

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
  double _discountTotal = 0;
  final List<_PaymentEntry> _payments = [];

  double get _netPayable =>
      (widget.totalBill - _discountTotal).clamp(0.0, double.infinity);

  double get _receivedAmount => _payments.fold(0.0, (sum, e) => sum + e.amount);

  double get _remainingAmount =>
      (_netPayable - _receivedAmount).clamp(0.0, double.infinity);

  double get _changeAmount => _receivedAmount - _netPayable;

  bool get _hasCashPayment => _payments.any((e) => e.type == _PaymentType.cash);

  String get _invoiceLabel {
    final parts = widget.invoiceNumber.split('-');
    return '#${parts.last}';
  }

  // ── Show Add Discount bottom sheet ────────────────────────────────────────
  Future<void> _showDiscountSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiscountSheet(totalBill: widget.totalBill),
    );
    if (result != null && mounted) {
      setState(() => _discountTotal = result);
    }
  }

  // ── Show Cash bottom sheet ────────────────────────────────────────────────
  Future<void> _showCashSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CashSheet(remainingAmount: _remainingAmount),
    );
    if (result != null && result > 0 && mounted) {
      setState(() {
        _payments.add(_PaymentEntry(type: _PaymentType.cash, amount: result));
      });
    }
  }

  // ── Show MFS bottom sheet ─────────────────────────────────────────────────
  Future<void> _showMfsSheet() async {
    final result = await showModalBottomSheet<_PaymentEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MfsSheet(remainingAmount: _remainingAmount),
    );
    if (result != null && mounted) {
      setState(() => _payments.add(result));
    }
  }

  // ── Show Card bottom sheet ────────────────────────────────────────────────
  Future<void> _showCardSheet() async {
    final result = await showModalBottomSheet<_PaymentEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardSheet(remainingAmount: _remainingAmount),
    );
    if (result != null && mounted) {
      setState(() => _payments.add(result));
    }
  }

  // ── Remove a confirmed payment entry ─────────────────────────────────────
  Future<void> _editPayment(int index) async {
    final entry = _payments[index];

    if (entry.type == _PaymentType.cash) {
      final result = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CashSheet(
          // add current cash back so user can edit against full remaining
          remainingAmount: _remainingAmount + entry.amount,
          initialAmount: entry.amount,
        ),
      );

      if (result != null && result > 0 && mounted) {
        setState(() {
          _payments[index] = _PaymentEntry(type: _PaymentType.cash, amount: result);
        });
      }
      return;
    }

    // Keep existing simple behavior for non-cash entries.
    setState(() => _payments.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final hasPayments = _payments.isNotEmpty;

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
                  // ── Bill summary ────────────────────────────────────────
                  _AmountRow(
                    label: 'Total Bill (${widget.itemCount} Items)',
                    amount: widget.totalBill,
                  ),

                  // ── Add discount ────────────────────────────────────────
                  _DiscountButton(onTap: _showDiscountSheet),

                  // ── Net payable ─────────────────────────────────────────
                  _AmountRow(
                    label: 'Net Payable',
                    amount: _netPayable,
                    large: true,
                  ),

                  const _Divider(),

                  // ── Payment methods ─────────────────────────────────────
                  const _SectionTitle('Add a payment method'),

                  if (!hasPayments) ...[
                    // ── Unconfirmed state: show selectable rows ────────────
                    _PaymentMethodRow(
                      leading: _CashLogo(),
                      title: 'Cash',
                      onTap: _showCashSheet,
                    ),
                    _PaymentMethodRow(
                      leading: _MfsLogo(),
                      title: 'MFS',
                      onTap: _showMfsSheet,
                    ),
                    _PaymentMethodRow(
                      leading: _CreditCardsLogo(),
                      title: 'Credit or debit card',
                      onTap: _showCardSheet,
                    ),
                    _PaymentMethodRow(
                      leading: _BanglaQrLogo(),
                      title: 'Bangla QR',
                      onTap: () {},
                      isLast: true,
                    ),
                  ] else ...[
                    // ── Confirmed payments list ────────────────────────────
                    for (int i = 0; i < _payments.length; i++)
                      _ConfirmedPaymentRow(
                        entry: _payments[i],
                        onEdit: () => _editPayment(i),
                        isLast:
                            i == _payments.length - 1 && _remainingAmount <= 0,
                      ),

                    // ── If still remaining, show add-more options ──────────
                    if (_remainingAmount > 0) ...[
                      if (!_hasCashPayment)
                        _PaymentMethodRow(
                          leading: _CashLogo(),
                          title: 'Cash',
                          onTap: _showCashSheet,
                        ),
                      _PaymentMethodRow(
                        leading: _MfsLogo(),
                        title: 'MFS',
                        onTap: _showMfsSheet,
                      ),
                      _PaymentMethodRow(
                        leading: _CreditCardsLogo(),
                        title: 'Credit or debit card',
                        onTap: _showCardSheet,
                      ),
                      _PaymentMethodRow(
                        leading: _BanglaQrLogo(),
                        title: 'Bangla QR',
                        onTap: () {},
                        isLast: true,
                      ),
                    ],
                  ],

                  const SizedBox(height: 6),

                  // ── Received amount ─────────────────────────────────────
                  _AmountRow(
                    label: 'Received Amount',
                    amount: _receivedAmount,
                    large: true,
                  ),

                  // ── Change / balance ────────────────────────────────────
                  _ChangeChip(change: _changeAmount),

                  const _Divider(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PrintBar(onPrint: widget.onPrintReceipt),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Discount Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DiscountSheet extends StatefulWidget {
  final double totalBill;
  const _DiscountSheet({required this.totalBill});

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  bool _isPercentage = true;
  final _ctrl = TextEditingController();
  double _parsedValue = 0;

  double get _discountAmount {
    if (_isPercentage) {
      return (widget.totalBill * _parsedValue / 100).clamp(
        0.0,
        widget.totalBill,
      );
    }
    return _parsedValue.clamp(0.0, widget.totalBill);
  }

  bool get _canApply => _parsedValue > 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add discount',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1117),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _ToggleTab(
                    label: 'Percentage',
                    selected: _isPercentage,
                    onTap: () => setState(() {
                      _isPercentage = true;
                      _ctrl.clear();
                      _parsedValue = 0;
                    }),
                  ),
                  _ToggleTab(
                    label: 'Amount',
                    selected: !_isPercentage,
                    onTap: () => setState(() {
                      _isPercentage = false;
                      _ctrl.clear();
                      _parsedValue = 0;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1117),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _isPercentage ? '% 0.00' : 'BDT 0.00',
                  hintStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFADB5BD),
                  ),
                ),
                onChanged: (v) {
                  setState(() => _parsedValue = double.tryParse(v) ?? 0);
                },
              ),
            ),
            if (_isPercentage && _canApply) ...[
              const SizedBox(height: 8),
              Text(
                'Discount: ৳ ${formatAmount(_discountAmount, keepTwoDecimals: true)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _canApply
                    ? () => Navigator.pop(context, _discountAmount)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1117),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply discount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _canApply ? Colors.white : const Color(0xFFADB5BD),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF0D1117)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cash Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CashSheet extends StatefulWidget {
  final double remainingAmount;
  final double? initialAmount;
  const _CashSheet({required this.remainingAmount, this.initialAmount});

  @override
  State<_CashSheet> createState() => _CashSheetState();
}

class _CashSheetState extends State<_CashSheet> {
  String _digits = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    if (initial != null && initial > 0) {
      _digits = _toInputDigits(initial);
    }
  }

  double get _enteredAmount {
    if (_digits.isEmpty) return 0;
    return double.tryParse(_digits) ?? 0;
  }

  bool get _canReceive => _enteredAmount > 0;

  String _toInputDigits(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _appendDigit(String d) {
    setState(() {
      if (d == '.' && _digits.contains('.')) return;
      if (_digits == '0' && d != '.') {
        _digits = d;
      } else {
        _digits += d;
      }
    });
  }

  void _deleteDigit() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enter cash amount',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1117),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Remaining amount chip
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '৳ ${formatAmount(widget.remainingAmount, keepTwoDecimals: true)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1117),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Remaining amount',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Display entered amount
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0D1117), width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              _digits.isEmpty
                  ? 'BDT 0.00'
                  : 'BDT ${formatAmount(double.tryParse(_digits) ?? 0, keepTwoDecimals: true)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1117),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Receive cash button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canReceive
                    ? () => Navigator.pop(context, _enteredAmount)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1117),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Receive cash',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _canReceive ? Colors.white : const Color(0xFFADB5BD),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Custom numpad
          _Numpad(
            onDigit: _appendDigit,
            onDelete: _deleteDigit,
            showDecimal: false,
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MFS Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MfsSheet extends StatefulWidget {
  final double remainingAmount;
  const _MfsSheet({required this.remainingAmount});

  @override
  State<_MfsSheet> createState() => _MfsSheetState();
}

class _MfsSheetState extends State<_MfsSheet> {
  String? _selectedProvider;
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  static const _providers = ['bKash', 'Nagad', 'Upay'];

  double get _enteredAmount => double.tryParse(_amountCtrl.text) ?? 0;
  bool get _isAmountWithinRemaining =>
      _enteredAmount > 0 && _enteredAmount <= widget.remainingAmount;

  bool get _canConfirm =>
      _selectedProvider != null &&
      _isAmountWithinRemaining &&
      (_phoneCtrl.text.length == 4);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafeInset = mediaQuery.padding.bottom;
    final sheetHeight = mediaQuery.size.height * 0.46;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomSafeInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pay with MFS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1117),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: _providers.map((p) {
                    final isSelected = _selectedProvider == p;
                    final isLast = p == _providers.last;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedProvider = p),
                        child: Container(
                          margin: EdgeInsets.only(right: isLast ? 0 : 10),
                          height: 76,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF0F4FF)
                                : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0D1117)
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _MfsProviderIcon(provider: p),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _OutlinedField(
                  controller: _amountCtrl,
                  hint: 'Enter amount',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                if (_amountCtrl.text.isNotEmpty && !_isAmountWithinRemaining) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Amount cannot be greater than remaining amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _OutlinedField(
                  controller: _phoneCtrl,
                  hint: 'Last 4 digits of number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canConfirm
                        ? () {
                            final amount = _enteredAmount;
                            if (amount <= 0 || amount > widget.remainingAmount) {
                              return;
                            }
                            Navigator.pop(
                              context,
                              _PaymentEntry(
                                type: _PaymentType.mfs,
                                amount: amount,
                                detail: _selectedProvider,
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1117),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _canConfirm ? Colors.white : const Color(0xFFADB5BD),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CardSheet extends StatefulWidget {
  final double remainingAmount;
  const _CardSheet({required this.remainingAmount});

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  String _digits = '';
  final _lastFourCtrl = TextEditingController();

  double get _enteredAmount {
    if (_digits.isEmpty) return 0;
    return double.tryParse(_digits) ?? 0;
  }

  bool get _isAmountWithinRemaining =>
      _enteredAmount > 0 && _enteredAmount <= widget.remainingAmount;

  bool get _canConfirm => _isAmountWithinRemaining && _lastFourCtrl.text.length == 4;

  void _appendDigit(String d) {
    setState(() {
      if (d == '.' && _digits.contains('.')) return;
      if (_digits == '0' && d != '.') {
        _digits = d;
      } else {
        _digits += d;
      }
    });
  }

  void _deleteDigit() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  @override
  void dispose() {
    _lastFourCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _enteredAmount > 0;
    final hasLastFour = _lastFourCtrl.text.length == 4;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Card Payment',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1117),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Remaining amount chip
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '৳ ${formatAmount(widget.remainingAmount, keepTwoDecimals: true)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1117),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Remaining amount',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Amount input row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasAmount
                    ? const Color(0xFF0D1117)
                    : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text(
                  '৳ ',
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
                Expanded(
                  child: Text(
                    _digits.isEmpty
                        ? 'Amount to charge'
                        : formatAmount(
                            double.tryParse(_digits) ?? 0,
                            keepTwoDecimals: true,
                          ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: hasAmount ? FontWeight.w700 : FontWeight.w400,
                      color: hasAmount
                          ? const Color(0xFF0D1117)
                          : const Color(0xFFADB5BD),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          if (_digits.isNotEmpty && !_isAmountWithinRemaining)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Amount cannot be greater than remaining amount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Last 4 digits input
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasLastFour
                    ? const Color(0xFF0D1117)
                    : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card_rounded,
                  color: hasLastFour
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFADB5BD),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lastFourCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Last 4 digits',
                      hintStyle: TextStyle(
                        color: Color(0xFFADB5BD),
                        fontSize: 15,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1117),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm
                    ? () {
                        if (_enteredAmount > widget.remainingAmount) return;
                        Navigator.pop(
                          context,
                          _PaymentEntry(
                            type: _PaymentType.card,
                            amount: _enteredAmount,
                            detail: _lastFourCtrl.text,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1117),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Confirm payment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _canConfirm ? Colors.white : const Color(0xFFADB5BD),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Numpad
          _Numpad(
            onDigit: _appendDigit,
            onDelete: _deleteDigit,
            showDecimal: false,
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Custom Numpad
// ─────────────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final bool showDecimal;

  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    this.showDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          for (final row in rows)
            Row(
              children: row
                  .map(
                    (d) => Expanded(
                      child: _NumKey(label: d, onTap: () => onDigit(d)),
                    ),
                  )
                  .toList(),
            ),
          Row(
            children: [
              Expanded(
                child: showDecimal
                    ? _NumKey(label: '.', onTap: () => onDigit('.'))
                    : const SizedBox(),
              ),
              Expanded(
                child: _NumKey(label: '0', onTap: () => onDigit('0')),
              ),
              Expanded(
                child: _NumKey(icon: Icons.backspace_outlined, onTap: onDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumKey({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: label != null
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0D1117),
                ),
              )
            : Icon(icon, size: 22, color: const Color(0xFF0D1117)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Outlined Text Field
// ─────────────────────────────────────────────────────────────────────────────

class _OutlinedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _OutlinedField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0D1117),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirmed Payment Row  (shown after user adds a payment)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmedPaymentRow extends StatelessWidget {
  final _PaymentEntry entry;
  final VoidCallback onEdit;
  final bool isLast;

  const _ConfirmedPaymentRow({
    required this.entry,
    required this.onEdit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
          bottom: isLast
              ? const BorderSide(color: Color(0xFFE5E7EB), width: 0.8)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 52, child: entry.logo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D1117),
              ),
            ),
          ),
          Text(
            '৳ ${formatAmount(entry.amount, keepTwoDecimals: true)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1117),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
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
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
  final VoidCallback onTap;
  const _DiscountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: OutlinedButton.icon(
        onPressed: onTap,
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
// Payment Method Row  (selectable, pre-payment)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final VoidCallback onTap;
  final bool isLast;

  const _PaymentMethodRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 72, child: leading),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C2230),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFADB5BD),
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
        color: shortfall ? const Color(0xFFFFE4E4) : const Color(0xFFDCECE6),
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
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: true,
        left: true,
        right: true,
        minimum: EdgeInsets.zero,
        child: Container(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method logo widgets
// ─────────────────────────────────────────────────────────────────────────────

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
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFF22C55E),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

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
            child: const Icon(
              Icons.phone_android_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

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
            child: const Icon(
              Icons.credit_card_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

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
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFF16A34A),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small provider icon used inside MFS sheet & confirmed row
class _MfsProviderIcon extends StatelessWidget {
  final String provider;
  const _MfsProviderIcon({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Map provider name → asset; fall back to a coloured icon
    final assetMap = {
      'bKash': 'assets/images/bkash-mfs.png',
      'Nagad': 'assets/images/nogod-mfs.png',
      'Upay': 'assets/images/upay-mfs.png',
    };
    final path = assetMap[provider];
    if (path != null) {
      return Image.asset(
        path,
        width: 68,
        height: 44,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(provider),
      );
    }
    return _fallback(provider);
  }

  Widget _fallback(String name) {
    return Container(
      width: 48,
      height: 36,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? 'MFS' : name[0],
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

/// Card icon that shows a network logo based on last 4 digits
class _CardIcon extends StatelessWidget {
  final String lastFour;
  const _CardIcon({required this.lastFour});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'VISA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
