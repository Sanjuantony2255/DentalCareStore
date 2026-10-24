import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_receipt_dialog.dart';
import '../widgets/empty_state_view.dart';

class SearchRecordsScreen extends StatefulWidget {
  final StorageService storage;

  const SearchRecordsScreen({super.key, required this.storage});

  @override
  State<SearchRecordsScreen> createState() => _SearchRecordsScreenState();
}

class _SearchRecordsScreenState extends State<SearchRecordsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openInvoice(Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => InvoiceReceiptDialog(invoice: inv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final allInvoices = widget.storage.invoices;
        final query = _searchController.text.trim().toLowerCase();

        final filtered = allInvoices.where((inv) {
          if (query.isEmpty) return true;
          return inv.patientName.toLowerCase().contains(query) ||
              inv.phone.contains(query) ||
              inv.id.toLowerCase().contains(query) ||
              inv.doctor.toLowerCase().contains(query) ||
              inv.paymentMode.toLowerCase().contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Search Records & Invoices'),
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by Invoice # (INV-...), Patient Name or Phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Invoices Found',
                        message: query.isNotEmpty
                            ? 'No invoice records match "$query".'
                            : 'No invoice transactions recorded yet.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final inv = filtered[index];
                          final isPending = inv.paymentMode.toLowerCase().contains('pending');

                          return Card(
                            child: InkWell(
                              onTap: () => _openInvoice(inv),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            inv.id,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            inv.paymentMode.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isPending ? const Color(0xFF92400E) : const Color(0xFF166534),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            inv.patientName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          currency.format(inv.totalAmount),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryTeal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${inv.phone} • Attending: ${inv.doctor}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 6),
                                        Text(
                                          inv.date,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          'Tap to inspect invoice →',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
