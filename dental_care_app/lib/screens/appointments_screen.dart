import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/appointment.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';

class AppointmentsScreen extends StatefulWidget {
  final StorageService storage;

  const AppointmentsScreen({super.key, required this.storage});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _callPatient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot launch call for $phone')),
      );
    }
  }

  void _openBookAppointmentModal([String? patientName, String? phone]) {
    final nameCtrl = TextEditingController(text: patientName ?? '');
    final phoneCtrl = TextEditingController(text: phone ?? '');
    final reasonCtrl = TextEditingController(text: 'Routine Dental Consultation');
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String timeSlot = '10:00 AM';
    String doctor = 'Dr. Sanju Antony';

    final doctors = [
      'Dr. Sanju Antony',
      'Dr. Sarah Mathew (Orthodontist)',
      'Dr. Jacob Thomas (Endodontist)',
    ];

    final timeSlots = [
      '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM',
      '11:30 AM', '02:00 PM', '02:30 PM', '04:00 PM', '05:30 PM'
    ];

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
                      'Book New Appointment',
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
                  decoration: const InputDecoration(labelText: 'Patient Name *', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: doctor,
                  decoration: const InputDecoration(labelText: 'Attending Doctor', prefixIcon: Icon(Icons.medical_services_outlined)),
                  items: doctors.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setModalState(() => doctor = v ?? doctors[0]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) setModalState(() => date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
                          child: Text(DateFormat('yyyy-MM-dd').format(date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: timeSlot,
                        decoration: const InputDecoration(labelText: 'Time Slot', prefixIcon: Icon(Icons.access_time)),
                        items: timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setModalState(() => timeSlot = v ?? timeSlots[0]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason for Visit', prefixIcon: Icon(Icons.healing_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.notes_outlined)),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter name and phone')),
                      );
                      return;
                    }

                    final apt = Appointment(
                      id: 'APT-${DateTime.now().millisecondsSinceEpoch % 100000}',
                      patientName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      doctor: doctor,
                      date: DateFormat('yyyy-MM-dd').format(date),
                      timeSlot: timeSlot,
                      reason: reasonCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      status: 'Upcoming',
                    );

                    await widget.storage.saveAppointment(apt);
                    ApiService.syncAppointmentOnline(apt);

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Appointment booked for ${apt.patientName}!'),
                        backgroundColor: AppTheme.primaryTeal,
                      ),
                    );
                  },
                  child: const Text('Confirm Appointment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRescheduleDialog(Appointment apt) {
    DateTime date = DateTime.tryParse(apt.date) ?? DateTime.now();
    String timeSlot = apt.timeSlot;
    final notesCtrl = TextEditingController(text: apt.notes);

    final timeSlots = [
      '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM',
      '11:30 AM', '02:00 PM', '02:30 PM', '04:00 PM', '05:30 PM'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Reschedule: ${apt.patientName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'New Date', prefixIcon: Icon(Icons.calendar_today)),
                    child: Text(DateFormat('yyyy-MM-dd').format(date)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: timeSlots.contains(timeSlot) ? timeSlot : timeSlots[0],
                  decoration: const InputDecoration(labelText: 'New Time Slot', prefixIcon: Icon(Icons.access_time)),
                  items: timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => timeSlot = v ?? timeSlots[0]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Reschedule Reason', prefixIcon: Icon(Icons.notes)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                await widget.storage.rescheduleAppointment(
                  apt.id,
                  dateStr,
                  timeSlot,
                  apt.doctor,
                  notesCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment rescheduled successfully!')),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final allApts = widget.storage.appointments;
        final todayApts = allApts.where((a) => a.date == todayStr).toList();
        final upcomingApts = allApts.where((a) {
          try {
            final dt = DateTime.parse(a.date);
            final today = DateTime.parse(todayStr);
            return dt.isAfter(today) && a.status != 'Cancelled';
          } catch (_) {
            return false;
          }
        }).toList();

        final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final datewiseApts = allApts.where((a) => a.date == selectedDateStr).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appointments & Calendar'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppTheme.primaryTeal,
              tabs: [
                Tab(text: 'Today (${todayApts.length})'),
                Tab(text: 'Upcoming (${upcomingApts.length})'),
                const Tab(text: 'Date Filter'),
                Tab(text: 'All (${allApts.length})'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openBookAppointmentModal(),
            backgroundColor: AppTheme.primaryTeal,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Book Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Today
              _buildAppointmentsList(todayApts, 'No appointments scheduled for today.'),

              // Tab 2: Upcoming
              _buildAppointmentsList(upcomingApts, 'No upcoming appointments.'),

              // Tab 3: Date Filter
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2028),
                              );
                              if (picked != null) setState(() => _selectedDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 20, color: AppTheme.primaryTeal),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.today, color: AppTheme.primaryTeal),
                          tooltip: 'Today',
                          onPressed: () => setState(() => _selectedDate = DateTime.now()),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: _buildAppointmentsList(
                      datewiseApts,
                      'No appointments for ${DateFormat('dd MMM yyyy').format(_selectedDate)}.',
                    ),
                  ),
                ],
              ),

              // Tab 4: All
              _buildAppointmentsList(allApts, 'No appointment history available.'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsList(List<Appointment> list, String emptyMessage) {
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_available_outlined,
        title: 'No Appointments Found',
        message: emptyMessage,
        buttonText: 'Book New Appointment',
        onButtonPressed: () => _openBookAppointmentModal(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final apt = list[index];
        final isCompleted = apt.status == 'Completed';
        final isCancelled = apt.status == 'Cancelled';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Patient Name + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        apt.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFDCFCE7)
                            : isCancelled
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        apt.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? const Color(0xFF166534)
                              : isCancelled
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date & Time row
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Text(
                      '${apt.date} at ${apt.timeSlot}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        apt.doctor,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          apt.reason.isNotEmpty ? apt.reason : 'Dental Consultation',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone, size: 20, color: AppTheme.primaryTeal),
                      tooltip: 'Call Patient',
                      onPressed: () => _callPatient(apt.phone),
                    ),
                    if (!isCompleted && !isCancelled) ...[
                      OutlinedButton(
                        onPressed: () => _openRescheduleDialog(apt),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Reschedule'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await widget.storage.updateAppointmentStatus(apt.id, 'Completed');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked as Completed')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Complete'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
