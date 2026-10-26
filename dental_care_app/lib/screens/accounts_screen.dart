import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/invoice.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/invoice_receipt_dialog.dart';

class AccountsScreen extends StatefulWidget {
  final StorageService storage;

  const AccountsScreen({super.key, required this.storage});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _selectedPeriod = 'all'; // 'today', 'week', 'month', 'all'

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
        final summary = widget.storage.getAccountsSummary(_selectedPeriod);

        final dailyTotal = summary['dailyTotal'] as double;
        final dailyVisits = summary['dailyVisits'] as int;
        final weeklyTotal = summary['weeklyTotal'] as double;
        final weeklyVisits = summary['weeklyVisits'] as int;
        final monthlyTotal = summary['monthlyTotal'] as double;
        final monthlyVisits = summary['monthlyVisits'] as int;
        final lifetimeTotal = summary['lifetimeTotal'] as double;
        final lifetimeVisits = summary['lifetimeVisits'] as int;

        final filteredRevenue = summary['filteredRevenue'] as double;
        final consultationTotal = summary['consultationTotal'] as double;
        final xrayTotal = summary['xrayTotal'] as double;
        final pharmacyTotal = summary['pharmacyTotal'] as double;

        final cashTotal = summary['cashTotal'] as double;
        final upiTotal = summary['upiTotal'] as double;
        final cardTotal = summary['cardTotal'] as double;
        final pendingTotal = summary['pendingTotal'] as double;

        final invoices = summary['invoices'] as List<Invoice>;

        // Percentages
        final consultPct = filteredRevenue > 0 ? (consultationTotal / filteredRevenue) : 0.0;
        final xrayPct = filteredRevenue > 0 ? (xrayTotal / filteredRevenue) : 0.0;
        final pharmacyPct = filteredRevenue > 0 ? (pharmacyTotal / filteredRevenue) : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Accounts & Revenue Dashboard'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4 Core Financial Metrics Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: "Today's Collections",
                      value: currency.format(dailyTotal),
                      subtitle: '$dailyVisits patient visits',
                      icon: Icons.today,
                      accentColor: AppTheme.primaryTeal,
                      onTap: () => setState(() => _selectedPeriod = 'today'),
                    ),
                    StatCard(
                      title: 'This Week',
                      value: currency.format(weeklyTotal),
                      subtitle: '$weeklyVisits patient visits',
                      icon: Icons.date_range,
                      accentColor: const Color(0xFF0284C7),
                      onTap: () => setState(() => _selectedPeriod = 'week'),
                    ),
                    StatCard(
                      title: 'This Month',
                      value: currency.format(monthlyTotal),
                      subtitle: '$monthlyVisits patient visits',
                      icon: Icons.calendar_month,
                      accentColor: const Color(0xFF7C3AED),
                      onTap: () => setState(() => _selectedPeriod = 'month'),
                    ),
                    StatCard(
                      title: 'Lifetime Total',
                      value: currency.format(lifetimeTotal),
                      subtitle: '$lifetimeVisits total records',
                      icon: Icons.account_balance_wallet,
                      accentColor: const Color(0xFF059669),
                      onTap: () => setState(() => _selectedPeriod = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Period Filter Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Analysis Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        items: const [
                          DropdownMenuItem(value: 'today', child: Text("Today's View")),
                          DropdownMenuItem(value: 'week', child: Text('Past 7 Days')),
                          DropdownMenuItem(value: 'month', child: Text('This Month')),
                          DropdownMenuItem(value: 'all', child: Text('Lifetime View')),
                        ],
                        onChanged: (v) => setState(() => _selectedPeriod = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Revenue Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Revenue by Clinical Category',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              currency.format(filteredRevenue),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _categoryBar(
                          '🩺 Doctor Consultation',
                          currency.format(consultationTotal),
                          consultPct,
                          AppTheme.primaryTeal,
                        ),
                        const SizedBox(height: 14),
                        _categoryBar(
                          '🩻 X-Ray & Radiology',
                          currency.format(xrayTotal),
                          xrayPct,
                          const Color(0xFF0284C7),
                        ),
                        const SizedBox(height: 14),
                        _categoryBar(
                          '💊 Pharmacy / Medicines',
                          currency.format(pharmacyTotal),
                          pharmacyPct,
                          const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Mode Breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Mode Distribution',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _paymentChip('Cash', currency.format(cashTotal), const Color(0xFF10B981))),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentChip('UPI', currency.format(upiTotal), const Color(0xFF6366F1))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _paymentChip('Card', currency.format(cardTotal), const Color(0xFF0284C7))),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentChip('Pending', currency.format(pendingTotal), const Color(0xFFEF4444))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions Audit Ledger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transactions Audit Ledger',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${invoices.length} entries',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (invoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No transactions recorded for selected period.')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final inv = invoices[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt, size: 20, color: AppTheme.primaryTeal),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inv.patientName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${inv.id} • ${inv.date} • ${inv.paymentMode}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currency.format(inv.totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openInvoice(inv),
                                    icon: const Icon(Icons.receipt_long, size: 14),
                                    label: const Text('Show Invoice'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryTeal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => InvoiceReceiptDialog.downloadInvoiceFile(context, inv),
                                    icon: const Icon(Icons.download, size: 14),
                                    label: const Text('Download Invoice'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryDark,
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoryBar(String title, String amount, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
            Text(
              '$amount (${(ratio * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _paymentChip(String mode, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(mode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            ],
          ),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
