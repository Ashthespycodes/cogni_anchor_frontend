import 'package:flutter/material.dart';
import 'package:cogni_anchor/services/patient_status_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cogni_anchor/services/pair_context.dart'; // ✅ ADD ONLY THIS
import 'package:cogni_anchor/presentation/constants/colors.dart' as colors;
import 'package:cogni_anchor/presentation/widgets/common/app_text.dart';
import 'package:cogni_anchor/presentation/screens/auth/signup_page.dart';
import 'package:cogni_anchor/presentation/screens/user_selection_page.dart';
import 'package:cogni_anchor/presentation/main_screen.dart';
import 'package:cogni_anchor/models/user_model.dart';
import 'package:cogni_anchor/presentation/screens/app_initializer.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;

      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 🔍 Check if role already exists
      final user = client.auth.currentUser!;
      final data = await client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data == null || data['role'] == null) {
        // New user → choose role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserSelectionPage()),
        );
      } else {
        final role = UserModel.values.firstWhere(
          (e) => e.name == data['role'],
        );

// ✅ MARK PATIENT LOGGED IN
        if (role == UserModel.patient) {
          await PatientStatusService.markLoggedIn();
        }

        await loadPairIntoContext(role);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppInitializer()),
          (_) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText("Welcome to CogniAnchor", fontWeight: FontWeight.bold),
            Gap(30.h),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            Gap(16.h),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            Gap(24.h),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.appColor,
                minimumSize: Size(double.infinity, 50.h),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage()),
                );
              },
              child: const Text("Create an account"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadPairIntoContext(UserModel role) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final query = role == UserModel.patient
        ? client
            .from('pairs')
            .select('id')
            .eq('patient_user_id', user.id)
            .maybeSingle()
        : client
            .from('pairs')
            .select('id')
            .eq('caretaker_user_id', user.id)
            .maybeSingle();

    final pair = await query;

    if (pair != null && pair['id'] != null) {
      PairContext.set(pair['id']);
    } else {
      PairContext.clear();
    }
  }
}
