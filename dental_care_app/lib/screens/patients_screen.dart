import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../models/invoice.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/invoice_receipt_dialog.dart';

class PatientsScreen extends StatefulWidget {
  final StorageService storage;
  final Function(String name, String phone)? onBookAppointment;

  const PatientsScreen({
    super.key,
    required this.storage,
    this.onBookAppointment,
  });

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  String _activeFilter = 'all'; // 'all', 'male', 'female', 'revisit'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _callPatient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openInvoice(Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => InvoiceReceiptDialog(invoice: inv),
    );
  }

  Invoice _findOrCreateInvoiceForVisit(Patient p, VisitRecord v) {
    if (v.invoiceId.isNotEmpty) {
      final found = widget.storage.invoices.where((i) => i.id == v.invoiceId || i.id.toLowerCase() == v.invoiceId.toLowerCase());
      if (found.isNotEmpty) return found.first;
    }
    final match = widget.storage.invoices.where((i) =>
      i.patientName.toLowerCase() == p.name.toLowerCase() && i.date == v.date
    );
    if (match.isNotEmpty) return match.first;

    return Invoice(
      id: v.invoiceId.isNotEmpty ? v.invoiceId : 'INV-${v.date.replaceAll('/', '').replaceAll('-', '')}',
      patientName: p.name,
      phone: p.phone,
      doctor: v.doctor.isNotEmpty ? v.doctor : p.doctor,
      date: v.date,
      consultationCharge: v.amount,
      xrayCharge: 0.0,
      pharmacyCharge: 0.0,
      totalAmount: v.amount,
      paymentMode: 'Cash',
      notes: v.notes,
    );
  }

  void _showPatientDetailsModal(Patient patient) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      patient.opNumber.isNotEmpty ? patient.opNumber : patient.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Patient Avatar & Name
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryTeal,
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${patient.age > 0 ? '${patient.age} yrs • ' : ''}${patient.gender} • Registered ${patient.registrationDate}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Contact & Fast Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callPatient(patient.phone),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(patient.phone),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (widget.onBookAppointment != null) {
                          widget.onBookAppointment!(patient.name, patient.phone);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Book Visit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Medical Profile Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _metaRow('Attending Doctor', patient.doctor),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Medical Conditions', patient.medicalHistory),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Drug Allergies', patient.drugAllergies, isAlert: patient.drugAllergies.toLowerCase() != 'none'),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Dental Complaint', patient.diseaseHistory),
                    if (patient.address.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _metaRow('Address', patient.address),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row (Visits & Billed)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Visits', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            '${patient.totalVisits}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lifetime Billed', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(patient.totalBilled),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Past Visits Timeline
              const Text(
                'Clinical Visit History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),

              if (patient.visits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recorded previous visits.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: patient.visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final visit = patient.visits[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      visit.date,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      currency.format(visit.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppTheme.primaryTeal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  visit.notes,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'By ${visit.doctor} • Inv #${visit.invoiceId}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final inv = _findOrCreateInvoiceForVisit(patient, visit);
                                        _openInvoice(inv);
                                      },
                                      icon: const Icon(Icons.receipt_long, size: 14),
                                      label: const Text('Show Invoice'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryTeal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: Size.zero,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final inv = _findOrCreateInvoiceForVisit(patient, visit);
                                        InvoiceReceiptDialog.downloadInvoiceFile(context, inv);
                                      },
                                      icon: const Icon(Icons.download, size: 14),
                                      label: const Text('Download Invoice'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryDark,
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: Size.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {bool isAlert = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final allPatients = widget.storage.patients;
        final query = _searchController.text.trim().toLowerCase();
        final qDigits = query.replaceAll(RegExp(r'\D'), '');

        final filtered = allPatients.where((p) {
          final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
          final matchesQuery = query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              p.phone.contains(query) ||
              (qDigits.length >= 3 && pDigits.contains(qDigits)) ||
              p.opNumber.toLowerCase().contains(query) ||
              p.doctor.toLowerCase().contains(query) ||
              p.diseaseHistory.toLowerCase().contains(query) ||
              p.medicalHistory.toLowerCase().contains(query) ||
              p.drugAllergies.toLowerCase().contains(query) ||
              p.address.toLowerCase().contains(query);

          if (!matchesQuery) return false;

          if (_activeFilter == 'male') return p.gender.toLowerCase() == 'male';
          if (_activeFilter == 'female') return p.gender.toLowerCase() == 'female';
          if (_activeFilter == 'revisit') return p.totalVisits > 1;

          return true;
        }).toList();

        final totalVisits = allPatients.fold<int>(0, (sum, p) => sum + p.totalVisits);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Registered Patients Directory'),
          ),
          body: Column(
            children: [
              // Top Stats Banner
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _headerPill('👥 ${allPatients.length} Patients', const Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    _headerPill('🩺 $totalVisits Total Visits', const Color(0xFF0284C7)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Search Bar & Filter Pills
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search patients by name, phone or OP #...',
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
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _filterChip('Revisit Patients', 'revisit'),
                          const SizedBox(width: 8),
                          _filterChip('Male', 'male'),
                          const SizedBox(width: 8),
                          _filterChip('Female', 'female'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Patients List
              Expanded(
                child: filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => widget.storage.syncWithCloud(),
                        child: const SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: 350,
                            child: EmptyStateView(
                              icon: Icons.person_search_outlined,
                              title: 'No Patients Match',
                              message: 'Try adjusting your search query or filter criteria.',
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => widget.storage.syncWithCloud(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                          final p = filtered[index];
                          final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

                          return Card(
                            child: InkWell(
                              onTap: () => _showPatientDetailsModal(p),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppTheme.primarySubtle,
                                      child: Text(
                                        p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  p.name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                p.opNumber,
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${p.phone} • ${p.age > 0 ? '${p.age}y • ' : ''}${p.gender}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${p.totalVisits} ${p.totalVisits == 1 ? 'visit' : 'visits'}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Billed: ${currency.format(p.totalBilled)}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.primaryTeal),
                                      tooltip: 'Call Patient',
                                      onPressed: () => _callPatient(p.phone),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _filterChip(String label, String key) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = key),
      selectedColor: AppTheme.primarySubtle,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primaryDark : const Color(0xFF475569),
      ),
    );
  }
}
