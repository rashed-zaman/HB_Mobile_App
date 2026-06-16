import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/customer_service.dart';

export '../models/customer.dart';

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class SearchCustomerScreen extends StatefulWidget {
  /// Called when user taps a customer row.
  /// Returns the selected [Customer] to the caller via Navigator.pop.
  const SearchCustomerScreen({super.key});

  @override
  State<SearchCustomerScreen> createState() => _SearchCustomerScreenState();
}

class _SearchCustomerScreenState extends State<SearchCustomerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final CustomerService _customerService = CustomerService();

  static const int _pageSize = 20;

  Timer? _debounce;
  List<Customer> _results = [];
  int _currentPage = -1;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _fetch(append: false);
    });
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasViewportDimension) return;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _fetch(append: true);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _fetch(append: false);
    });
  }

  Future<void> _fetch({required bool append}) async {
    if (_loadingMore && append) return;
    if (_loading && !append) return;

    final query = _searchController.text.trim();
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
      final result = await _customerService.fetchCustomers(
        page: page,
        size: _pageSize,
        search: query,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _results.addAll(result.customers);
        } else {
          _results = result.customers;
        }
        _currentPage = page;
        if (append && result.customers.isEmpty) {
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
        _error = e is CustomerException ? e.message : e.toString();
        if (!append) {
          _results = [];
          _currentPage = -1;
          _hasMore = false;
        }
      });
    }
  }

  void _selectCustomer(Customer customer) {
    Navigator.of(context).pop(customer);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _customerService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'Customers'
                    : 'Search Results',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C4E),
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null && _results.isEmpty) {
      return _ErrorState(message: _error!, onRetry: () => _fetch(append: false));
    }

    if (_results.isEmpty) {
      return const _EmptyResult();
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 72,
        endIndent: 0,
        color: Color(0xFFE5E5EA),
      ),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
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
        return _CustomerTile(
          customer: _results[index],
          query: _searchController.text.trim(),
          onTap: () => _selectCustomer(_results[index]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 1.2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF3C3C4E),
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                hintText: 'Search Member name, Phone, ID...',
                hintStyle: TextStyle(fontSize: 15, color: Color(0xFFAEAEB2)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox(width: 14);
              return GestureDetector(
                onTap: () => controller.clear(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFAEAEB2),
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Customer Tile
// ─────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final String query;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFF0F0F5),
      highlightColor: const Color(0xFFF8F8FA),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFAEAEB2),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: customer.name,
                    query: query,
                    baseStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                    highlightStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      backgroundColor: Color(0xFFFFE566),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Code: ${customer.code}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      if (customer.phone.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '-',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            customer.phone,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF8E8E93),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D1D6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );
      start = index + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 56,
            color: Color(0xFFD1D1D6),
          ),
          SizedBox(height: 16),
          Text(
            'No customers found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try a different name, phone or ID',
            style: TextStyle(fontSize: 13, color: Color(0xFFAEAEB2)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFD1D1D6)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
