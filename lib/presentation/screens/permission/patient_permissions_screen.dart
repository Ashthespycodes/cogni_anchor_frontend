import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cogni_anchor/services/patient_status_service.dart';
import 'package:cogni_anchor/presentation/screens/app_initializer.dart';

class PatientPermissionsScreen extends StatefulWidget {
  const PatientPermissionsScreen({super.key});

  @override
  State<PatientPermissionsScreen> createState() =>
      _PatientPermissionsScreenState();
}

class _PatientPermissionsScreenState extends State<PatientPermissionsScreen> {
  bool _locationGranted = false;
  bool _micGranted = false;
  bool _loading = false;

  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadExistingPermissionState();
  }

  // 🔄 Load current permission state from DB (if any)
  Future<void> _loadExistingPermissionState() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final status = await _client
          .from('patient_status')
          .select('location_permission, mic_permission')
          .eq('patient_user_id', user.id)
          .maybeSingle();

      if (status != null && mounted) {
        setState(() {
          _locationGranted = status['location_permission'] ?? false;
          _micGranted = status['mic_permission'] ?? false;
        });
      }
    } catch (_) {
      // silent fail
    }
  }

  // 📍 REQUEST LOCATION PERMISSION
  Future<void> _requestLocation() async {
    setState(() => _loading = true);

    try {
      // 1️⃣ Request foreground location FIRST
      final foregroundStatus = await Permission.location.request();

      if (!foregroundStatus.isGranted) {
        await _updateLocationPermission(false);
        if (mounted) {
          setState(() => _locationGranted = false);
        }
        return;
      }

      // 2️⃣ Then request background location
      final backgroundStatus = await Permission.locationAlways.request();

      final granted = backgroundStatus.isGranted;

      await _updateLocationPermission(granted);

      if (mounted) {
        setState(() => _locationGranted = granted);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateLocationPermission(bool granted) async {
    await _client.from('patient_status').update({
      'location_permission': granted,
    }).eq('patient_user_id', _client.auth.currentUser!.id);
  }

  // 🎤 REQUEST MICROPHONE PERMISSION
  Future<void> _requestMic() async {
    setState(() => _loading = true);

    try {
      final status = await Permission.microphone.request();

      final granted = status.isGranted;

      if (mounted) {
        setState(() => _micGranted = granted);
      }

      await _client.from('patient_status').update({
        'mic_permission': granted,
      }).eq('patient_user_id', _client.auth.currentUser!.id);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ Continue - save decision to database even if denied
  Future<void> _continue() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Ensure patient_status record exists with current permission states
    try {
      await _client.from('patient_status').upsert({
        'patient_user_id': user.id,
        'location_permission': _locationGranted,
        'mic_permission': _micGranted,
      });
    } catch (e) {
      debugPrint('Error saving permission state: $e');
    }

    await PatientStatusService.updateLastActive();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppInitializer()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            // 🔶 HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFFFF653A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Text(
                'Permissions Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 40),

            _permissionTile(
              title: 'Allow location access',
              subtitle:
                  'This allows your caretaker to see your live location if needed.',
              granted: _locationGranted,
              onTap: _requestLocation,
            ),

            const SizedBox(height: 20),

            _permissionTile(
              title: 'Allow microphone access',
              subtitle:
                  'This allows your caretaker to hear audio in emergencies.',
              granted: _micGranted,
              onTap: _requestMic,
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF653A),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 UI TILE (UNCHANGED STYLE)
  Widget _permissionTile({
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          granted
              ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
              : ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF653A),
                  ),
                  child: const Text("Allow"),
                ),
        ],
      ),
    );
  }
}
