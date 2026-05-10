import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────
class Customer {
  final String name;
  final String code;
  final String phone;

  const Customer({required this.name, required this.code, required this.phone});
}

// ─────────────────────────────────────────────────────────────
// Sample data (replace with API/DB call)
// ─────────────────────────────────────────────────────────────
const List<Customer> _allCustomers = [
  Customer(
    name: 'General Customer',
    code: 'Cust - 00000',
    phone: '01673-XXXXXX',
  ),
  Customer(name: 'Hasan khan', code: 'Cust - 00001', phone: '01854886330'),
  Customer(name: 'Raju khan', code: 'Cust - 00002', phone: '01854886330'),
  Customer(name: 'Karim Hasan', code: 'Cust - 00003', phone: '+8801734345'),
  Customer(name: 'Hasan khan', code: 'Cust - 00004', phone: '+8801734345'),
  Customer(name: 'Rahim Uddin', code: 'Cust - 00005', phone: '01711223344'),
  Customer(name: 'Fatema Begum', code: 'Cust - 00006', phone: '01955667788'),
];

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
  List<Customer> _results = _allCustomers;

  @override
  void initState() {
    super.initState();
    // Auto-focus keyboard on open (mirrors the screenshot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _results = _allCustomers;
      } else {
        _results = _allCustomers
            .where(
              (c) =>
                  c.name.toLowerCase().contains(query) ||
                  c.code.toLowerCase().contains(query) ||
                  c.phone.contains(query),
            )
            .toList();
      }
    });
  }

  void _selectCustomer(Customer customer) {
    // Pop and return the selected customer to the previous screen
    Navigator.of(context).pop(customer);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
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
            // ── Search Bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Section Label ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'Recent Customers'
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

            // ── Customer List ─────────────────────────────────
            Expanded(
              child: _results.isEmpty
                  ? const _EmptyResult()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 0,
                        color: Color(0xFFE5E5EA),
                      ),
                      itemBuilder: (context, index) {
                        return _CustomerTile(
                          customer: _results[index],
                          query: _searchController.text.trim(),
                          onTap: () => _selectCustomer(_results[index]),
                        );
                      },
                    ),
            ),
          ],
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
          // Back arrow
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

          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                hintText: 'Search Member name, Phone,ID...',
                hintStyle: TextStyle(fontSize: 15, color: Color(0xFFAEAEB2)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          // Clear button (visible when text is present)
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
            // Avatar
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

            // Name + code + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Highlighted name
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

                  // Code + phone row
                  Row(
                    children: [
                      Text(
                        'Code: ${customer.code}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
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
                  ),
                ],
              ),
            ),

            // Chevron
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

// ─────────────────────────────────────────────────────────────
// Highlight matching text
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// Standalone entry point for previewing this screen alone
// ─────────────────────────────────────────────────────────────
void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Search Customer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
      ),
      home: const SearchCustomerScreen(),
    );
  }
}
