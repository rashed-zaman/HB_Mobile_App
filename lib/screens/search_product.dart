import 'package:flutter/material.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

enum StockStatus { inStock, lowStock, outOfStock }

class Product {
  final String name;
  final String code;
  final int stock;
  final double price;

  const Product({
    required this.name,
    required this.code,
    required this.stock,
    required this.price,
  });

  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.outOfStock;
    if (stock <= 5) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  String get stockLabel {
    if (stock == 0) return 'Stock: Out';
    return 'Stock: $stock Pcs';
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) || code.toLowerCase().contains(q);
  }
}

// ─── Sample Data ─────────────────────────────────────────────────────────────

const List<Product> _allProducts = [
  Product(name: 'Classic Blue Lungi', code: 'M-03', stock: 45, price: 2700),
  Product(name: 'Classic Blue Lungi', code: 'M-03', stock: 0, price: 2700),
  Product(name: 'Classic Blue Lungi', code: 'F-01', stock: 5, price: 2700),
  Product(name: 'Classic Blue Lungi', code: 'F-01', stock: 5, price: 2700),
  Product(name: 'Classic White Lungi', code: 'W-01', stock: 20, price: 3200),
  Product(name: 'Premium Silk Lungi', code: 'S-05', stock: 8, price: 5500),
  Product(name: 'Cotton Stripe Lungi', code: 'C-12', stock: 0, price: 1800),
  Product(name: 'Royal Check Lungi', code: 'R-07', stock: 3, price: 4100),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class SearchProductScreen extends StatefulWidget {
  /// Called when the user taps a product. Receives the selected [Product].
  final ValueChanged<Product>? onProductSelected;

  const SearchProductScreen({super.key, this.onProductSelected});

  @override
  State<SearchProductScreen> createState() => _SearchProductScreenState();
}

class _SearchProductScreenState extends State<SearchProductScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Product> _results = _allProducts;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    // Auto-focus the search field when the screen opens
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    setState(() {
      _results = _allProducts.where((p) => p.matchesQuery(query)).toList();
    });
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildSectionLabel(),
            const SizedBox(height: 8),
            Expanded(child: _buildProductList()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        'Select Product',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A2E),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          children: [
            // Back / search icon
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Color(0xFF555555),
                ),
              ),
            ),

            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search by name or code…',
                  hintStyle: TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),

            // Clear button
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: _clearQuery,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8E8E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        _controller.text.isEmpty
            ? 'Recent Product'
            : 'Results (${_results.length})',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ── Product List ──────────────────────────────────────────────────────────

  Widget _buildProductList() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No products found',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) => _ProductTile(
        product: _results[index],
        onTap: () => widget.onProductSelected?.call(_results[index]),
      ),
    );
  }
}

// ─── Product Tile ─────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const _ProductTile({required this.product, this.onTap});

  Color get _stockColor {
    switch (product.stockStatus) {
      case StockStatus.outOfStock:
        return const Color(0xFFE53935);
      case StockStatus.lowStock:
        return const Color(0xFFE67E22);
      case StockStatus.inStock:
        return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: Color(0xFF999999),
                ),
              ),

              const SizedBox(width: 12),

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Code: ${product.code}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '|',
                            style: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          product.stockLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _stockColor,
                            fontWeight:
                                product.stockStatus != StockStatus.inStock
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Price
              Text(
                '৳ ${_formatPrice(product.price)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price % 1 == 0) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }
}
