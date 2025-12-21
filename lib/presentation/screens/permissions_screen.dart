import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cogni_anchor/services/pair_context.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cogni_anchor/presentation/screens/permission/caregiver_live_map_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool locationEnabled = false;
  bool microphoneEnabled = false;

  bool _loadingLocation = false;
  bool _loadingMic = false;

  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _requestBackgroundLocation() async {
    // Step 1: Foreground permission
    final fg = await Permission.location.request();
    if (!fg.isGranted) {
      _showMsg("Location permission denied");
      return;
    }

    // Step 2: Background permission
    final bg = await Permission.locationAlways.request();
    if (!bg.isGranted) {
      _showMsg("Allow location all the time for live tracking");
      return;
    }
  }

  // 🔄 Load current toggle state from DB
  Future<void> _loadCurrentStatus() async {
    try {
      final pairId = PairContext.pairId;
      if (pairId == null) return;

      final pair = await _client
          .from('pairs')
          .select('patient_user_id')
          .eq('id', pairId)
          .maybeSingle();

      if (pair == null) return;

      final status = await _client
          .from('patient_status')
          .select('location_toggle_on, mic_toggle_on')
          .eq('patient_user_id', pair['patient_user_id'])
          .maybeSingle();

      if (status != null && mounted) {
        setState(() {
          locationEnabled = status['location_toggle_on'] ?? false;
          microphoneEnabled = status['mic_toggle_on'] ?? false;
        });
      }
    } catch (_) {
      _showMsg("Failed to load patient status");
    }
  }

  // 📍 LOCATION TOGGLE LOGIC
  Future<void> _toggleLocation(bool value) async {
    if (_loadingLocation) return;

    setState(() => _loadingLocation = true);

    try {
      final pairId = PairContext.pairId;
      if (pairId == null) {
        _showMsg("No patient paired");
        return;
      }

      final pair = await _client
          .from('pairs')
          .select('patient_user_id')
          .eq('id', pairId)
          .single();

      final status = await _client
          .from('patient_status')
          .select('is_logged_in, location_permission')
          .eq('patient_user_id', pair['patient_user_id'])
          .single();

      if (status['is_logged_in'] != true) {
        _showMsg("Patient is logged out");
        return;
      }

      if (status['location_permission'] != true) {
        _showMsg("Patient denied location access");
        return;
      }
      if (value == true) {
        await _requestBackgroundLocation();
      }

      await _client
          .from('patient_status')
          .update({'location_toggle_on': value}).eq(
              'patient_user_id', pair['patient_user_id']);

      setState(() => locationEnabled = value);
    } catch (_) {
      _showMsg("Failed to update location sharing");
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  // 🎤 MICROPHONE TOGGLE LOGIC
  Future<void> _toggleMic(bool value) async {
    if (_loadingMic) return;

    setState(() => _loadingMic = true);

    try {
      final pairId = PairContext.pairId;
      if (pairId == null) {
        _showMsg("No patient paired");
        return;
      }

      final pair = await _client
          .from('pairs')
          .select('patient_user_id')
          .eq('id', pairId)
          .single();

      final status = await _client
          .from('patient_status')
          .select('is_logged_in, mic_permission')
          .eq('patient_user_id', pair['patient_user_id'])
          .single();

      if (status['is_logged_in'] != true) {
        _showMsg("Patient is logged out");
        return;
      }

      if (status['mic_permission'] != true) {
        _showMsg("Patient denied microphone access");
        return;
      }

      await _client.from('patient_status').update({'mic_toggle_on': value}).eq(
          'patient_user_id', pair['patient_user_id']);

      setState(() => microphoneEnabled = value);
    } catch (_) {
      _showMsg("Failed to update microphone sharing");
    } finally {
      setState(() => _loadingMic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            // 🔶 TOP APP BAR
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Turn on live location and\nmicrophone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 🔹 LOCATION TOGGLE
            _permissionTile(
              title: 'Allow app to access your location',
              value: locationEnabled,
              onChanged: _loadingLocation ? null : _toggleLocation,
            ),
            if (locationEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF653A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CaregiverLiveMapScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "View Live Location",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // 🔹 MICROPHONE TOGGLE
            _permissionTile(
              title: 'Allow app to access your microphone',
              value: microphoneEnabled,
              onChanged: _loadingMic ? null : _toggleMic,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 REUSABLE TOGGLE TILE (UNCHANGED UI)
  Widget _permissionTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF2ED573),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  // 🔔 SNACKBAR HELPER
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
