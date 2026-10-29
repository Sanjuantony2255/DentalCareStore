import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../constants/treatments.dart';

class AppointmentsScreen extends StatefulWidget {
  final StorageService storage;

  const AppointmentsScreen({super.key, required this.storage});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.storage.patients.isEmpty) {
      widget.storage.syncWithCloud();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _callPatient(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch call for $phone')),
        );
      }
    }
  }

  void _openTreatmentSelectSheet(BuildContext parentCtx, void Function(String) onSelect) {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = kDentalTreatments.where((t) {
            if (query.isEmpty) return true;
            return t.toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Treatment for Appointment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search from ${kDentalTreatments.length} treatments...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No treatments matched your search.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final treatment = filtered[idx];

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primarySubtle,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.healing_outlined,
                                    size: 16,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                title: Text(
                                  treatment,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onSelect(treatment);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openBookAppointmentModal([String? patientName, String? phone]) {
    final nameCtrl = TextEditingController(text: patientName ?? '');
    final phoneCtrl = TextEditingController(text: phone ?? '');
    final reasonCtrl = TextEditingController(text: 'CONSULTATION');
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String timeSlot = '10:00 AM';
    String doctor = kClinicDoctors[0];
    final manualDoctorCtrl = TextEditingController();

    Patient? selectedPatient;
    List<Patient> nameSuggestions = [];
    List<Patient> phoneSuggestions = [];

    // Pre-match registered patient if initial values were provided
    if ((patientName != null && patientName.isNotEmpty) || (phone != null && phone.isNotEmpty)) {
      final cleanP = (phone ?? '').replaceAll(RegExp(r'\D'), '');
      final cleanN = (patientName ?? '').trim().toLowerCase();
      try {
        selectedPatient = widget.storage.patients.firstWhere((p) {
          final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
          final pN = p.name.trim().toLowerCase();
          return (cleanP.isNotEmpty && pDigits == cleanP) || (cleanN.isNotEmpty && pN == cleanN);
        });
      } catch (_) {}
    }

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
        builder: (ctx, setModalState) {
          void selectPatient(Patient p) {
            nameCtrl.text = p.name;
            phoneCtrl.text = p.phone;
            if (p.doctor.isNotEmpty) {
              final docMatch = kClinicDoctors.firstWhere(
                (d) => d.toLowerCase().contains(p.doctor.toLowerCase()) || p.doctor.toLowerCase().contains(d.toLowerCase()),
                orElse: () => '',
              );
              if (docMatch.isNotEmpty) {
                doctor = docMatch;
              }
            }
            selectedPatient = p;
            nameSuggestions = [];
            phoneSuggestions = [];
            setModalState(() {});
          }

          void onNameChanged(String val) {
            final q = val.trim().toLowerCase();
            if (q.isEmpty) {
              setModalState(() {
                nameSuggestions = [];
                if (selectedPatient != null && selectedPatient!.name.trim().toLowerCase() != q) {
                  selectedPatient = null;
                }
              });
              return;
            }
            final matches = widget.storage.patients.where((p) {
              final pName = p.name.trim().toLowerCase();
              final pPhone = p.phone.replaceAll(RegExp(r'\D'), '');
              return pName.contains(q) || (q.length >= 3 && pPhone.contains(q));
            }).take(5).toList();

            setModalState(() {
              nameSuggestions = matches;
              phoneSuggestions = [];
              if (selectedPatient != null && selectedPatient!.name.trim().toLowerCase() != q) {
                selectedPatient = null;
              }
            });
          }

          void onPhoneChanged(String val) {
            final qDigits = val.replaceAll(RegExp(r'\D'), '');
            if (qDigits.length < 2) {
              setModalState(() {
                phoneSuggestions = [];
                if (selectedPatient != null && selectedPatient!.phone.replaceAll(RegExp(r'\D'), '') != qDigits) {
                  selectedPatient = null;
                }
              });
              return;
            }
            final matches = widget.storage.patients.where((p) {
              final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
              return pDigits.contains(qDigits);
            }).take(5).toList();

            setModalState(() {
              phoneSuggestions = matches;
              nameSuggestions = [];
              if (selectedPatient != null && selectedPatient!.phone.replaceAll(RegExp(r'\D'), '') != qDigits) {
                selectedPatient = null;
              }
            });
          }

          Widget buildSuggestionCard(List<Patient> list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: AppTheme.primaryDark),
                        const SizedBox(width: 6),
                        Text(
                          'Registered Patients (${list.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                        ),
                        const Spacer(),
                        const Text(
                          'Tap to select',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  ...list.map((p) {
                    final op = p.opNumber.isNotEmpty ? p.opNumber : (p.id.isNotEmpty ? 'OP-${p.id.replaceAll(RegExp(r'\D'), '')}' : '');
                    return InkWell(
                      onTap: () => selectPatient(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 11, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.phone,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (op.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  op,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }

          return Padding(
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
                    decoration: InputDecoration(
                      labelText: 'Patient Name *',
                      hintText: 'Type to search registered patients...',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: nameCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                nameCtrl.clear();
                                onNameChanged('');
                              },
                            )
                          : null,
                    ),
                    onChanged: onNameChanged,
                  ),
                  if (nameSuggestions.isNotEmpty) buildSuggestionCard(nameSuggestions),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'Type to suggest by phone...',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: phoneCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                phoneCtrl.clear();
                                onPhoneChanged('');
                              },
                            )
                          : null,
                    ),
                    onChanged: onPhoneChanged,
                  ),
                  if (phoneSuggestions.isNotEmpty) buildSuggestionCard(phoneSuggestions),
                  if (selectedPatient != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF34D399)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Registered Patient: ${selectedPatient!.name} (${selectedPatient!.opNumber.isNotEmpty ? selectedPatient!.opNumber : "Registered"})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedPatient = null;
                              });
                            },
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: doctor,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Attending Doctor', prefixIcon: Icon(Icons.medical_services_outlined)),
                    items: kClinicDoctors.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setModalState(() => doctor = v ?? kClinicDoctors[0]),
                  ),
                  if (doctor == 'Other (Type Manually)') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: manualDoctorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type Doctor Name Manually *',
                        prefixIcon: Icon(Icons.person_add_alt_outlined),
                        hintText: 'e.g. Dr. Jeswin Jose BDS',
                      ),
                    ),
                  ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Treatment / Procedure',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                      InkWell(
                        onTap: () => _openTreatmentSelectSheet(ctx, (t) {
                          setModalState(() => reasonCtrl.text = t);
                        }),
                        child: const Text(
                          'Browse All 58 Treatments →',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'CONSULTATION',
                        'SCALING',
                        'RCT',
                        'COMPOSITE',
                        'CROWN PFM',
                        'POST & CORE',
                        'NORMAL EXTRACTION',
                        'CLEAR ALIGNERS',
                        'OTHER / ANY OPTION',
                      ].map((t) {
                        final isSel = reasonCtrl.text == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(t, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? AppTheme.primaryDark : const Color(0xFF334155))),
                            backgroundColor: isSel ? AppTheme.primarySubtle : const Color(0xFFF1F5F9),
                            side: BorderSide(color: isSel ? AppTheme.primaryTeal : const Color(0xFFCBD5E1)),
                            onPressed: () => setModalState(() => reasonCtrl.text = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Treatment / Reason *',
                      prefixIcon: const Icon(Icons.healing_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.list_alt_rounded, color: AppTheme.primaryTeal),
                        tooltip: 'Select treatment',
                        onPressed: () => _openTreatmentSelectSheet(ctx, (t) {
                          setModalState(() => reasonCtrl.text = t);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.notes_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Google Calendar Sync Active (manjalymdc@gmail.com): Notification push reminders will be scheduled for this appointment.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
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

                      final effectiveDoctor = doctor == 'Other (Type Manually)'
                          ? (manualDoctorCtrl.text.trim().isNotEmpty
                              ? manualDoctorCtrl.text.trim()
                              : 'Attending Doctor')
                          : doctor;

                      final apt = Appointment(
                        id: 'APT-${DateTime.now().millisecondsSinceEpoch % 100000}',
                        patientName: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        doctor: effectiveDoctor,
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
                          content: Text('✓ Appointment booked & synced to Google Calendar (manjalymdc@gmail.com) for ${apt.patientName}!'),
                          backgroundColor: AppTheme.primaryTeal,
                        ),
                      );
                    },
                    child: const Text('Confirm Appointment & Sync'),
                  ),
                ],
              ),
            ),
          );
        },
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
                  const SnackBar(content: Text('✓ Appointment rescheduled & synced to Google Calendar (manjalymdc@gmail.com)!')),
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

        final query = _searchController.text.trim().toLowerCase();
        final qDigits = query.replaceAll(RegExp(r'\D'), '');

        bool matchesQuery(Appointment a) {
          if (query.isEmpty) return true;
          final aDigits = a.phone.replaceAll(RegExp(r'\D'), '');
          return a.patientName.toLowerCase().contains(query) ||
              a.phone.contains(query) ||
              (qDigits.length >= 3 && aDigits.contains(qDigits)) ||
              a.doctor.toLowerCase().contains(query) ||
              a.reason.toLowerCase().contains(query) ||
              a.status.toLowerCase().contains(query) ||
              a.notes.toLowerCase().contains(query);
        }

        final filteredToday = todayApts.where(matchesQuery).toList();
        final filteredUpcoming = upcomingApts.where(matchesQuery).toList();
        final filteredDatewise = datewiseApts.where(matchesQuery).toList();
        final filteredAll = allApts.where(matchesQuery).toList();

        return Scaffold(
          appBar: AppBar(
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search patient, doctor, reason...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
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
                  )
                : const Text('Appointments & Calendar'),
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                tooltip: _showSearch ? 'Close Search' : 'Search Appointments',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchController.clear();
                  });
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppTheme.primaryTeal,
              tabs: [
                Tab(text: 'Today (${filteredToday.length})'),
                Tab(text: 'Upcoming (${filteredUpcoming.length})'),
                const Tab(text: 'Date Filter'),
                Tab(text: 'All (${filteredAll.length})'),
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
              _buildAppointmentsList(
                filteredToday,
                query.isNotEmpty
                    ? 'No appointments today matched "$query".'
                    : 'No appointments scheduled for today.',
              ),

              // Tab 2: Upcoming
              _buildAppointmentsList(
                filteredUpcoming,
                query.isNotEmpty
                    ? 'No upcoming appointments matched "$query".'
                    : 'No upcoming appointments.',
              ),

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
                      filteredDatewise,
                      query.isNotEmpty
                          ? 'No appointments on ${DateFormat('dd MMM yyyy').format(_selectedDate)} matched "$query".'
                          : 'No appointments for ${DateFormat('dd MMM yyyy').format(_selectedDate)}.',
                    ),
                  ),
                ],
              ),

              // Tab 4: All
              _buildAppointmentsList(
                filteredAll,
                query.isNotEmpty
                    ? 'No appointments matched "$query".'
                    : 'No appointment history available.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsList(List<Appointment> list, String emptyMessage) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => widget.storage.syncWithCloud(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: EmptyStateView(
              icon: Icons.event_available_outlined,
              title: 'No Appointments Found',
              message: emptyMessage,
              buttonText: 'Book New Appointment',
              onButtonPressed: () => _openBookAppointmentModal(),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => widget.storage.syncWithCloud(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
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
    ),
  );
}
}
