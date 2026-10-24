import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/empty_state_view.dart';

class PharmacyScreen extends StatefulWidget {
  final StorageService storage;

  const PharmacyScreen({super.key, required this.storage});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final _searchController = TextEditingController();
  String _activeCategory = 'all';

  final List<String> _categories = [
    'all',
    'Medicines',
    'Anesthetics',
    'Dental Materials',
    'Consumables',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddItemModal() {
    final nameCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: 'BATCH-${DateTime.now().year}-${DateTime.now().month}');
    final priceCtrl = TextEditingController(text: '150');
    final qtyCtrl = TextEditingController(text: '20');
    final thresholdCtrl = TextEditingController(text: '10');
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));
    String category = 'Medicines';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Pharmacy / Dental Item',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item / Medicine Name *', prefixIcon: Icon(Icons.medication)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                  items: _categories
                      .where((c) => c != 'all')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModalState(() => category = v ?? 'Medicines'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: batchCtrl,
                        decoration: const InputDecoration(labelText: 'Batch Number', prefixIcon: Icon(Icons.qr_code)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) setModalState(() => expiryDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Expiry Date', prefixIcon: Icon(Icons.event)),
                          child: Text(DateFormat('yyyy-MM-dd').format(expiryDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Unit Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.inventory_2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low Stock Alert Threshold',
                    prefixIcon: Icon(Icons.warning_amber),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;

                    final item = InventoryItem(
                      id: 'MED-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      name: nameCtrl.text.trim(),
                      category: category,
                      batch: batchCtrl.text.trim(),
                      expiryDate: DateFormat('yyyy-MM-dd').format(expiryDate),
                      unitPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                      quantity: int.tryParse(qtyCtrl.text) ?? 0,
                      minStockThreshold: int.tryParse(thresholdCtrl.text) ?? 10,
                    );

                    await widget.storage.saveInventoryItem(item);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${item.name} to pharmacy inventory!')),
                    );
                  },
                  child: const Text('Add to Inventory'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final summary = widget.storage.getStockSummary();
        final allItems = widget.storage.inventory;
        final query = _searchController.text.trim().toLowerCase();

        final filtered = allItems.where((i) {
          final matchesQuery = query.isEmpty ||
              i.name.toLowerCase().contains(query) ||
              i.batch.toLowerCase().contains(query) ||
              i.category.toLowerCase().contains(query);

          if (!matchesQuery) return false;
          if (_activeCategory != 'all' && i.category != _activeCategory) return false;

          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pharmacy & Stock Inventory'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddItemModal,
            backgroundColor: AppTheme.primaryTeal,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4 Stock Metric Cards
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: 'Total Stock Items',
                      value: '${summary['totalItems']}',
                      subtitle: 'Active catalog items',
                      icon: Icons.inventory,
                      accentColor: AppTheme.primaryTeal,
                    ),
                    StatCard(
                      title: 'Low Stock Alerts',
                      value: '${summary['lowStockCount']}',
                      subtitle: 'Below threshold level',
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFEF4444),
                    ),
                    StatCard(
                      title: 'Expiring Soon',
                      value: '${summary['expiringSoonCount']}',
                      subtitle: 'Within next 90 days',
                      icon: Icons.hourglass_bottom_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    StatCard(
                      title: 'Stock Valuation',
                      value: currency.format(summary['totalValuation']),
                      subtitle: 'Total inventory value',
                      icon: Icons.monetization_on_outlined,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search medicines, anesthetics, batches...',
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
                const SizedBox(height: 12),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) {
                      final isSelected = _activeCategory == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c == 'all' ? 'All Items' : c),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _activeCategory = c),
                          selectedColor: AppTheme.primarySubtle,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primaryDark : const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Inventory Items List
                if (filtered.isEmpty)
                  EmptyStateView(
                    icon: Icons.medication_outlined,
                    title: 'No Pharmacy Items Found',
                    message: 'No stock items match your criteria.',
                    buttonText: 'Add New Item',
                    onButtonPressed: _openAddItemModal,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isLow = item.isLowStock;
                      final isExpiring = item.isExpiringSoon;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.category} • Batch: ${item.batch}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currency.format(item.unitPrice),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryTeal,
                                        ),
                                      ),
                                      const Text(
                                        'per unit',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Badges row: Exp date, low stock, expiring warning
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Exp: ${item.expiryDate}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isLow)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'LOW STOCK',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                      ),
                                    ),
                                  if (isExpiring) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'EXPIRING SOON',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Stock Counter & Quick Adjust Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('In Stock: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                      Text(
                                        '${item.quantity} units',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isLow ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.remove, size: 16),
                                        onPressed: item.quantity > 0
                                            ? () => widget.storage.adjustStock(item.id, -1)
                                            : null,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton.filled(
                                        icon: const Icon(Icons.add, size: 16),
                                        onPressed: () => widget.storage.adjustStock(item.id, 1),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}
