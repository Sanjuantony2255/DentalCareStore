import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_password_dialog.dart';
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

  Future<void> _requestAdminSwitch(BuildContext context, {VoidCallback? onSuccess}) async {
    if (widget.storage.isAdmin) {
      onSuccess?.call();
      return;
    }
    final granted = await promptAdminPassword(context);
    if (granted) {
      await widget.storage.setUserRole('admin');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👑 Admin mode unlocked successfully'),
            backgroundColor: Color(0xFF0F766E),
            duration: Duration(seconds: 2),
          ),
        );
      }
      setState(() {});
      onSuccess?.call();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Incorrect admin password'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showRoleSwitchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Select User Role', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose your clinic portal access level:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: widget.storage.isAdmin ? AppTheme.primarySubtle : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: widget.storage.isAdmin ? AppTheme.primaryTeal : const Color(0xFFE2E8F0)),
              ),
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Text('👑')),
              title: const Text('Admin (Dr. Jeswin)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Full rights: Patients, Appointments, Invoices, Accounts & Revenue', style: TextStyle(fontSize: 11)),
              trailing: widget.storage.isAdmin ? const Icon(Icons.check_circle, color: AppTheme.primaryTeal) : null,
              onTap: () async {
                Navigator.pop(ctx);
                if (!widget.storage.isAdmin) {
                  await _requestAdminSwitch(context);
                }
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: !widget.storage.isAdmin ? const Color(0xFFFEF3C7) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: !widget.storage.isAdmin ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
              ),
              leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Text('👤')),
              title: const Text('Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Clinic rights: Patients, Appointments & Invoices (Accounts restricted)', style: TextStyle(fontSize: 11)),
              trailing: !widget.storage.isAdmin ? const Icon(Icons.check_circle, color: Color(0xFFB45309)) : null,
              onTap: () {
                widget.storage.setUserRole('staff');
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStaffAccountsRestrictedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 44, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Admin Access Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only clinic administrators (Dr. Jeswin) have the right to view Accounts & Revenue analytics. Staff accounts are restricted from accessing financial data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  label: const Text('Switch to Admin Mode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _requestAdminSwitch(context),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 0),
                  child: const Text('Return to Registration & Patients'),
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
    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final isAdmin = widget.storage.isAdmin;

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
          isAdmin ? AccountsScreen(storage: widget.storage) : _buildStaffAccountsRestrictedView(),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manjaly Dental',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Multi Speciality Dental Clinic',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Role Switcher Chip (Admin / Staff)
              GestureDetector(
                onTap: () => _showRoleSwitchDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isAdmin ? '👑' : '👤', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        isAdmin ? 'Admin (Dr. Jeswin)' : 'Staff',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                      'Live',
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
                      const SizedBox(height: 14),
                      // Drawer Role Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(context);
                                  if (!isAdmin) {
                                    await _requestAdminSwitch(context);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '👑 Admin (Dr. Jeswin)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isAdmin ? const Color(0xFF0F766E) : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  widget.storage.setUserRole('staff');
                                  Navigator.pop(context);
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !isAdmin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '👤 Staff',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: !isAdmin ? const Color(0xFF0F766E) : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      _drawerItem(
                        4,
                        isAdmin ? Icons.bar_chart_outlined : Icons.lock_outline,
                        isAdmin ? 'Accounts & Revenue' : 'Accounts & Revenue (Admin 🔒)',
                      ),
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
                                Text('Dr. Jeswin (Owner & Admin)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('📞 +91 9072467117 / 6238497517', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal)),
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
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment, color: AppTheme.primaryDark),
                label: 'Register',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month, color: AppTheme.primaryDark),
                label: 'Schedule',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people, color: AppTheme.primaryDark),
                label: 'Patients',
              ),
              const NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search, color: AppTheme.primaryDark),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(isAdmin ? Icons.bar_chart_outlined : Icons.lock_outline),
                selectedIcon: Icon(isAdmin ? Icons.bar_chart : Icons.lock, color: AppTheme.primaryDark),
                label: isAdmin ? 'Accounts' : 'Accounts 🔒',
              ),
            ],
          ),
        );
      },
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
