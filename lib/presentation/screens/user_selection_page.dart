import 'package:cogni_anchor/presentation/widgets/common/app_text.dart';
import 'package:cogni_anchor/presentation/constants/colors.dart' as colors;
import 'package:cogni_anchor/models/user_model.dart';
import 'package:cogni_anchor/presentation/main_screen.dart';
import 'package:cogni_anchor/presentation/screens/reminder/bloc/reminder_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserSelectionPage extends StatefulWidget {
  const UserSelectionPage({super.key});

  @override
  State<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  bool _isLoading = false;

  Future<void> _selectRole(UserModel role) async {
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Update user role in database
      await client.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'role': role.name,
      });

      // If user is a patient, create a pair for them
      if (role == UserModel.patient) {
        // Check if pair already exists
        final existingPair = await client
            .from('pairs')
            .select('id')
            .eq('patient_user_id', user.id)
            .maybeSingle();

        // Only create if pair doesn't exist
        if (existingPair == null) {
          await client.from('pairs').insert({
            'patient_user_id': user.id,
            // caretaker_user_id is null initially - will be set when caretaker connects
          });
        }
      }

      // If user is a caretaker, check if they have a pair
      if (role == UserModel.caretaker) {
        final existingPair = await client
            .from('pairs')
            .select('id')
            .eq('caretaker_user_id', user.id)
            .maybeSingle();

        // If no pair exists, create one for the caretaker
        if (existingPair == null) {
          await client.from('pairs').insert({
            'patient_user_id': user.id, // Caretaker is their own "patient" for now
            'caretaker_user_id': user.id,
          });
        }
      }

      if (!mounted) return;

      // Navigate to main screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ReminderBloc(),
            child: MainScreen(userModel: role),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 30.w),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText("I am a", fontSize: 40.sp, fontWeight: FontWeight.bold),
                    SizedBox(height: 10.h),
                    AppText(
                      "Select the option that best suits you",
                      fontSize: 14.sp,
                      textAlign: TextAlign.center,
                      color: Colors.grey[600]!,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: colors.appColor))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildRoleCard(
                            title: "Patient",
                            subtitle: "I am living with dementia",
                            icon: Icons.person,
                            color: colors.appColor,
                            onTap: () => _selectRole(UserModel.patient),
                          ),
                          SizedBox(height: 30.h),
                          _buildRoleCard(
                            title: "Caretaker",
                            subtitle: "I am caring for someone with dementia",
                            icon: Icons.favorite,
                            color: Colors.teal,
                            onTap: () => _selectRole(UserModel.caretaker),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(30.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 60.sp, color: color),
            SizedBox(height: 15.h),
            AppText(
              title,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            SizedBox(height: 8.h),
            AppText(
              subtitle,
              fontSize: 14.sp,
              textAlign: TextAlign.center,
              color: Colors.grey[600]!,
            ),
          ],
        ),
      ),
    );
  }
}
