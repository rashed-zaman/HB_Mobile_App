import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import 'payment_screen.dart';          // ← new
import 'quantity_bottom_sheet.dart';
import 'search_customer.dart';
import 'search_product.dart';

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B2C POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const POSScreen(),
    );
  }
}

class CartItem {
  final String name;
  final double price;
  final String? code;
  int quantity;

  CartItem({
    required this.name,
    required this.price,
    this.code,
    this.quantity = 1,
  });
}

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
      ((parts.length > 1 && (keepTwoDecimals || !isWhole)) ? '.${parts[1]}' : '');
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cartItems = [];
  Customer? _selectedCustomer;

  final List<Map<String, dynamic>> _products = [
    {'name': 'Rice (1kg)', 'price': 65.0, 'barcode': '8901234567890'},
    {'name': 'Cooking Oil (1L)', 'price': 185.0, 'barcode': '8901234567891'},
    {'name': 'Sugar (1kg)', 'price': 120.0, 'barcode': '8901234567892'},
    {'name': 'Dal (500g)', 'price': 95.0, 'barcode': '8901234567893'},
    {'name': 'Salt (1kg)', 'price': 40.0, 'barcode': '8901234567894'},
  ];

  List<Map<String, dynamic>> _filteredProducts = [];
  bool _showSuggestions = false;

  double get _totalPayable =>
      _cartItems.fold(0, (sum, item) => sum + item.price * item.quantity);

  int get _totalItems =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  String get _invoiceNumber {
    if (_cartItems.isEmpty) return '---';
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.millisecondsSinceEpoch % 10000}';
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _filteredProducts = [];
        _showSuggestions = false;
      });
      return;
    }
    final results = _products
        .where(
          (p) =>
              p['name'].toString().toLowerCase().contains(value.toLowerCase()) ||
              p['barcode'].toString().contains(value),
        )
        .toList();
    setState(() {
      _filteredProducts = results;
      _showSuggestions = results.isNotEmpty;
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final barcode = product['barcode']?.toString() ?? '';
      final existing = _cartItems.firstWhere(
        (item) => barcode.isNotEmpty
            ? item.code == barcode
            : item.name == product['name'],
        orElse: () => CartItem(name: '', price: 0),
      );
      if (existing.name.isNotEmpty) {
        existing.quantity++;
      } else {
        _cartItems.add(CartItem(
          name: product['name'] as String,
          price: (product['price'] as num).toDouble(),
          code: barcode.isEmpty ? null : barcode,
        ));
      }
      _showSuggestions = false;
      _searchController.clear();
      _filteredProducts = [];
    });
  }

  void _addProductFromSearch(Product product, {int quantity = 1}) {
    if (quantity < 1) return;
    setState(() {
      final existing = _cartItems.firstWhere(
        (item) => product.code.isNotEmpty
            ? item.code == product.code
            : item.name == product.name,
        orElse: () => CartItem(name: '', price: 0),
      );
      if (existing.name.isNotEmpty) {
        existing.quantity += quantity;
      } else {
        _cartItems.add(CartItem(
          name: product.name,
          price: product.price,
          code: product.code.isEmpty ? null : product.code,
          quantity: quantity,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  Future<void> _editCartItemQuantity(int index) async {
    if (index < 0 || index >= _cartItems.length) return;
    final item = _cartItems[index];
    final qty = await showQuantitySheet(
      context,
      product: Product(
        name: item.name,
        code: item.code ?? '',
        stock: 0,
        price: item.price,
      ),
      initialQuantity: item.quantity,
      actionText: 'Update item',
      detailsText: item.code != null && item.code!.isNotEmpty
          ? 'Code: ${item.code}'
          : 'Cart item',
    );
    if (!mounted || qty == null) return;
    setState(() => _cartItems[index].quantity = qty);
  }

  // ── Checkout → Loading → PaymentScreen ─────────────────────────────────────
  void _checkout() {
    if (_cartItems.isEmpty) return;
    final invoice = _invoiceNumber;
    final items = List<CartItem>.from(_cartItems);
    final total = _totalPayable;
    final totalItems = _totalItems;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CheckoutLoadingScreen(
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _cartItems.clear();
              _nameController.clear();
              _phoneController.clear();
              _selectedCustomer = null;
            });
          },
          // Build the destination after loading animation
          destinationBuilder: (onPrint) => PaymentScreen(   // ← new
            invoiceNumber: invoice,
            itemCount: totalItems,
            totalBill: total,
            onPrintReceipt: onPrint,
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomerSearch() async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => const SearchCustomerScreen()),
    );
    if (!mounted || customer == null) return;
    setState(() {
      _selectedCustomer = customer;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone;
    });
  }

  Future<void> _openProductSearch() async {
    final result =
        await Navigator.of(context).push<({Product product, int quantity})>(
      MaterialPageRoute(builder: (_) => const SearchProductScreen()),
    );
    if (!mounted || result == null) return;
    _addProductFromSearch(result.product, quantity: result.quantity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          _Header(
            invoiceNumber: _invoiceNumber,
            nameController: _nameController,
            phoneController: _phoneController,
            selectedCustomer: _selectedCustomer,
            onCashCustomerTap: _openCustomerSearch,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Product Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _openProductSearch,
                        child: AbsorbPointer(
                          child: _SearchBar(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                      if (_showSuggestions)
                        _SuggestionsDropdown(
                          products: _filteredProducts,
                          onSelect: _addToCart,
                        ),
                      const SizedBox(height: 16),
                      _cartItems.isEmpty
                          ? const _EmptyState()
                          : _CartList(
                              items: _cartItems,
                              onRemove: _removeItem,
                              onTapItem: _editCartItemQuantity,
                            ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomBar(
        totalItems: _totalItems,
        totalPayable: _totalPayable,
        onCheckout: _cartItems.isNotEmpty ? _checkout : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String invoiceNumber;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Customer? selectedCustomer;
  final VoidCallback onCashCustomerTap;

  const _Header({
    required this.invoiceNumber,
    required this.nameController,
    required this.phoneController,
    required this.onCashCustomerTap,
    this.selectedCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF3D1A2E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Text(
                'Invoice no: $invoiceNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onCashCustomerTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedCustomer?.name ?? 'Cash Customer',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedCustomer?.code ?? 'Cust-00000',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF8E8E93)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HeaderField(
                      controller: nameController,
                      icon: Icons.person_outline_rounded,
                      hint: 'Add name',
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderField(
                      controller: phoneController,
                      icon: Icons.phone_outlined,
                      hint: 'Mobile number',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: false, signed: false),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const _HeaderField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        style:
            const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8E8E93)),
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded,
              color: Color(0xFF8E8E93), size: 22),
          hintText: 'Scan or search item...',
          hintStyle:
              TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Suggestions Dropdown
// ─────────────────────────────────────────────────────────────
class _SuggestionsDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _SuggestionsDropdown(
      {required this.products, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: products.map((p) {
          return InkWell(
            onTap: () => onSelect(p),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 18, color: Color(0xFF3D1A2E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  Text(
                    '৳${p['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D1A2E),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: Colors.white, size: 38),
                ),
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('0',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'No items added yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search or scan barcode to add products\nto the invoice',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF8E8E93), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cart List
// ─────────────────────────────────────────────────────────────
class _CartList extends StatelessWidget {
  final List<CartItem> items;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onTapItem;

  const _CartList({
    required this.items,
    required this.onRemove,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTapItem(i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: Color(0xFFECECEC), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 33 / 2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202124),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onRemove(i),
                        child: const Icon(Icons.delete_outline,
                            color: Color(0xFFDA4F45), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.code != null && item.code!.isNotEmpty
                        ? 'Code: ${item.code} | UOM: Pcs'
                        : 'UOM: Pcs',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6F7277)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Qty: ${item.quantity.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF555B65)),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'TK ${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1D22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom Checkout Bar
// ─────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int totalItems;
  final double totalPayable;
  final VoidCallback? onCheckout;

  const _BottomBar({
    required this.totalItems,
    required this.totalPayable,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = onCheckout != null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Payable ($totalItems Items)',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                  Text(
                    '৳ ${formatAmount(totalPayable)}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF8E8E93),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onCheckout,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Checkout',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFD1D1D6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

// ─────────────────────────────────────────────────────────────
// Checkout Loading Screen  (unchanged, but builder-pattern)
// ─────────────────────────────────────────────────────────────

class _CheckoutLoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final Widget Function(VoidCallback onPrint) destinationBuilder;

  const _CheckoutLoadingScreen({
    required this.onComplete,
    required this.destinationBuilder,
  });

  @override
  State<_CheckoutLoadingScreen> createState() =>
      _CheckoutLoadingScreenState();
}

class _CheckoutLoadingScreenState extends State<_CheckoutLoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.destinationBuilder(() {
            widget.onComplete();
            Navigator.of(context).pop();
          }),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Column(
        children: [
          _CheckoutTopStripe(),
          const Expanded(child: Center(child: _DotLoader())),
        ],
      ),
    );
  }
}

class _DotLoader extends StatefulWidget {
  const _DotLoader();

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final active = (_ctrl.value * 3).floor() % 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == active
                    ? const Color(0xFF3B3B3E)
                    : const Color(0xFFD3D3D6),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _CheckoutTopStripe extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: 44 + topInset,
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0C0A10),
            Color(0xFF132746),
            Color(0xFF1C2439),
          ],
        ),
      ),
    );
  }
}