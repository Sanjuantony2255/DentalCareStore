import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'registration_screen.dart';
import 'appointments_screen.dart';
import 'patients_screen.dart';
import 'search_records_screen.dart';
import 'accounts_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;

  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onBookAppointmentFromPatient(String name, String phone) {
    setState(() => _currentIndex = 1);
  }

  void _handleSyncGoogleSheet(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Syncing with GitHub Cloud & Google Sheet...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await widget.storage.syncWithCloud();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Synced with GitHub Cloud & Google Sheet! (${widget.storage.patients.length} patients, ${widget.storage.appointments.length} appointments, ${widget.storage.invoices.length} invoices)'
              : 'Sync complete (using cached offline records)',
        ),
        backgroundColor: success ? AppTheme.primaryTeal : const Color(0xFF64748B),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      RegistrationScreen(
        storage: widget.storage,
        onNavigateToAppointments: () => setState(() => _currentIndex = 1),
      ),
      AppointmentsScreen(storage: widget.storage),
      PatientsScreen(
        storage: widget.storage,
        onBookAppointment: _onBookAppointmentFromPatient,
      ),
      SearchRecordsScreen(
        storage: widget.storage,
        onBookAppointment: _onBookAppointmentFromPatient,
      ),
      AccountsScreen(storage: widget.storage),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manjaly Dental Care',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Multi Speciality Dental Clinic',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Sync with GitHub Cloud & Google Sheet',
            onPressed: () => _handleSyncGoogleSheet(context),
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Cloud Live',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Manjaly Dental',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Multi Speciality Dental Care & Surgery',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(0, Icons.assignment_outlined, 'Registration & Billing'),
                  _drawerItem(1, Icons.calendar_month_outlined, 'Appointments & Calendar'),
                  _drawerItem(2, Icons.people_alt_outlined, 'Patients Directory'),
                  _drawerItem(3, Icons.search_outlined, 'Search Records & Invoices'),
                  _drawerItem(4, Icons.bar_chart_outlined, 'Accounts & Revenue'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryTeal),
                    title: const Text(
                      'Sync with Cloud',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                    ),
                    subtitle: const Text(
                      'GitHub Cloud & Google Sheet Live Sync',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    onTap: () {
                      Navigator.pop(context);
                      _handleSyncGoogleSheet(context);
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primarySubtle,
                        child: Text('👨‍⚕️', style: TextStyle(fontSize: 18)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attending Doctor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('manjalymdc@gmail.com', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Divider(height: 1, color: Color(0xFFE2E8F0)),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, size: 14, color: Color(0xFFEF4444)),
                      SizedBox(width: 6),
                      Text(
                        'Developed by Sanju Antony',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: Colors.white,
        elevation: 4,
        indicatorColor: AppTheme.primarySubtle,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: AppTheme.primaryDark),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppTheme.primaryDark),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people, color: AppTheme.primaryDark),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppTheme.primaryDark),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primaryDark),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryTeal : const Color(0xFF64748B)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryTeal : const Color(0xFF1E293B),
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primarySubtle.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}
