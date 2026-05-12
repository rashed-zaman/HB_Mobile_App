import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/inventory_service.dart';
import 'quantity_bottom_sheet.dart'; // ← new import

class SearchProductScreen extends StatefulWidget {
  /// Called when the user confirms a product + quantity.
  /// Receives the selected [Product] and the chosen [quantity].
  final void Function(Product product, int quantity)? onProductSelected;

  const SearchProductScreen({super.key, this.onProductSelected});

  @override
  State<SearchProductScreen> createState() => _SearchProductScreenState();
}

class _SearchProductScreenState extends State<SearchProductScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final InventoryService _inventory = InventoryService();

  static const int _pageSize = 10;

  Timer? _debounce;
  List<Product> _items = [];
  int _currentPage = -1;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _fetch(append: false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _inventory.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasViewportDimension) return;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _fetch(append: true);
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _fetch(append: false);
    });
  }

  Future<void> _fetch({required bool append}) async {
    if (_loadingMore && append) return;
    if (_loading && !append) return;

    final query = _controller.text.trim();
    final page = append ? _currentPage + 1 : 0;

    setState(() {
      _error = null;
      if (!append) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await _inventory.fetchItems(
        page: page,
        size: _pageSize,
        search: query,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _items.addAll(result.items);
        } else {
          _items = result.items;
        }
        _currentPage = page;
        if (append && result.items.isEmpty) {
          _hasMore = false;
        } else {
          _hasMore = !result.last;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e is InventoryException ? e.message : e.toString();
        if (!append) {
          _items = [];
          _currentPage = -1;
          _hasMore = false;
        }
      });
    }
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _retry() => _fetch(append: false);

  // ── product tap handler ────────────────────────────────────────────────────

  Future<void> _onProductTap(Product product) async {
    // Unfocus keyboard before showing sheet so it doesn't fight the numpad
    _focusNode.unfocus();

    final qty = await showQuantitySheet(context, product: product);

    if (qty == null || !mounted) return; // user dismissed

    void completeSelection() {
      if (!mounted) return;
      if (widget.onProductSelected != null) {
        widget.onProductSelected!(product, qty);
      } else {
        Navigator.of(context).pop((product: product, quantity: qty));
      }
    }

    // Second route.pop must run after the modal sheet's pop finishes; otherwise
    // Navigator can assert !_debugLocked (navigator.dart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      completeSelection();
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────

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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

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
                onSubmitted: (_) => _fetch(append: false),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, _) {
                if (value.text.isEmpty) return const SizedBox(width: 10);
                return GestureDetector(
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel() {
    String label;
    if (_loading && _items.isEmpty) {
      label = 'Loading…';
    } else if (_controller.text.trim().isEmpty) {
      label = 'Products';
    } else {
      label = 'Results (${_items.length})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final product = _items[index];
        return _ProductTile(
          product: product,
          onTap: () => _onProductTap(product), // ← updated
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductTile  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

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
                            fontWeight: product.stockStatus != StockStatus.inStock
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