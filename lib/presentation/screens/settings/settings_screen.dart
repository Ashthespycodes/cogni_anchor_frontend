import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cogni_anchor/services/pair_context.dart';
import 'dementia_profile_screen.dart';
import 'package:cogni_anchor/services/patient_status_service.dart';
import 'change_password_screen.dart';
import 'terms_conditions_screen.dart';
import 'package:cogni_anchor/presentation/screens/auth/login_page.dart';
import 'edit_profile_screen.dart';
import 'package:cogni_anchor/models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel userModel;

  const SettingsScreen({super.key, required this.userModel});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  String? pairId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPair();
  }

  /// 🔄 Load pair info
  Future<void> _loadPair() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      if (widget.userModel == UserModel.patient) {
        final existing = await _client
            .from('pairs')
            .select()
            .eq('patient_user_id', user.id)
            .maybeSingle();

        if (existing == null) {
          final inserted = await _client
              .from('pairs')
              .insert({'patient_user_id': user.id})
              .select()
              .single();
          pairId = inserted['id'];
        } else {
          pairId = existing['id'];
        }
        PairContext.set(pairId!);
      }

      if (widget.userModel == UserModel.caretaker) {
        final existing = await _client
            .from('pairs')
            .select()
            .eq('caretaker_user_id', user.id)
            .maybeSingle();

        pairId = existing?['id'];
        if (pairId != null) {
          PairContext.set(pairId!);
        }
      }
    } catch (_) {
      _showMsg("Failed to load pairing info");
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  // ================= CARETAKER CONNECT =================

  Future<void> _connectToPatient(String enteredPairId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final cleanId = enteredPairId.trim();

    final pair =
        await _client.from('pairs').select().eq('id', cleanId).maybeSingle();

    if (pair == null) throw Exception("Invalid Pair ID");
    if (pair['caretaker_user_id'] != null) {
      throw Exception("Pair already connected");
    }

    await _client
        .from('pairs')
        .update({'caretaker_user_id': user.id}).eq('id', cleanId);

    setState(() {
      pairId = cleanId;
      PairContext.set(pairId!);
    });
  }

  void _showPairIdDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Connect to Patient"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Enter Patient Pair ID"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF653A),
            ),
            onPressed: () async {
              try {
                await _connectToPatient(controller.text);
                if (mounted) Navigator.pop(context);
              } catch (_) {
                _showMsg("Invalid Pair ID");
              }
            },
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  // ================= LOGOUT =================

  Future<void> _confirmLogout() async {
    showDialog(
      context: context,
      builder: (_) => _confirmDialog(
        title: "Log out?",
        message: "Are you sure you want to log out?",
        confirmText: "Yes",
        onConfirm: _logout,
      ),
    );
  }

  Future<void> _logout() async {
    Navigator.pop(context);

    // ✅ MARK PATIENT LOGGED OUT
    if (widget.userModel == UserModel.patient) {
      await PatientStatusService.markLoggedOut();
    }

    await _client.auth.signOut();
    PairContext.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ================= HELPERS =================

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("No"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF653A),
          ),
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _tile(Icons.edit_outlined, "Edit Profile",
                      () => _go(const EditProfileScreen())),

                  _tile(
                    Icons.person_outline,
                    "Person Living With Dementia's Profile",
                    () => _go(const DementiaProfileScreen()),
                  ),

                  // 👤 PATIENT → Pair ID with copy
                  if (widget.userModel == UserModel.patient && pairId != null)
                    _patientPairIdBox(),

                  // 👩‍⚕️ CARETAKER
                  if (widget.userModel == UserModel.caretaker)
                    pairId == null
                        ? _tile(
                            Icons.group_outlined,
                            "Connect to Patient",
                            _showPairIdDialog,
                          )
                        : _caretakerPairIdBox(),

                  _tile(Icons.lock_outline, "Change Password",
                      () => _go(const ChangePasswordScreen())),

                  _tile(Icons.description_outlined, "Terms and Conditions",
                      () => _go(const TermsConditionsScreen())),

                  const SizedBox(height: 20),

                  _logoutTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ================= PAIR ID UI =================

  Widget _patientPairIdBox() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Pair ID",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: SelectableText(pairId ?? "")),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pairId ?? ""));
                    _showMsg("Pair ID copied");
                  },
                ),
              ],
            ),
          ],
        ),
      );

  Widget _caretakerPairIdBox() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connected Pair ID",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(pairId ?? ""),
          ],
        ),
      );

  // ================= COMMON UI =================

  Widget _tile(IconData icon, String title, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Widget _logoutTile() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Log out',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: _confirmLogout,
        ),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Color(0xFFFF653A),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 36),
            ),
            SizedBox(width: 12),
            Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
