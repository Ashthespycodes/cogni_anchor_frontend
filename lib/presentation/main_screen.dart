import 'package:cogni_anchor/presentation/constants/colors.dart' as colors;
import 'package:cogni_anchor/presentation/screens/chatbot_page_functional.dart';
import 'package:cogni_anchor/presentation/screens/face_recog/fr_intro_page.dart';
import 'package:cogni_anchor/presentation/screens/reminder/reminder_page.dart';
import 'package:cogni_anchor/presentation/screens/settings/settings_screen.dart';
import 'package:cogni_anchor/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class MainScreen extends StatefulWidget {
  final UserModel userModel;

  const MainScreen({super.key, required this.userModel});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final orange = colors.appColor;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ReminderPage(userModel: widget.userModel),
      _EmergencyPage(userModel: widget.userModel),
      ChatbotPageFunctional(),
      FacialRecognitionPage(),
      SettingsScreen(userModel: widget.userModel),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: orange,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
        ),
        child: GNav(
          selectedIndex: _selectedIndex,
          onTabChange: (i) {
            setState(() => _selectedIndex = i);
          },

          haptic: true,
          gap: 6,
          iconSize: 26,
          tabBorderRadius: 12,

          color: Colors.white70,
          activeColor: Colors.white,

          tabBackgroundColor: Colors.white24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          mainAxisAlignment: MainAxisAlignment.center,

          tabs: [
            _navItem(index: 0, iconOutlined: Icons.alarm_rounded, iconFilled: Icons.alarm),
            _navItem(index: 1, iconOutlined: Icons.send_rounded, iconFilled: Icons.send),
            _navItem(index: 2, iconOutlined: Icons.chat_bubble_outline_rounded, iconFilled: Icons.chat_bubble),
            _navItem(index: 3, iconOutlined: Icons.face_outlined, iconFilled: Icons.face),
            _navItem(index: 4, iconOutlined: Icons.settings_outlined, iconFilled: Icons.settings),
          ],
        ),
      ),
    );
  }

  GButton _navItem({required int index, required IconData iconOutlined, required IconData iconFilled}) {
    return GButton(icon: _selectedIndex == index ? iconFilled : iconOutlined);
  }
}

// Emergency/Alert Page
class _EmergencyPage extends StatelessWidget {
  final UserModel userModel;

  const _EmergencyPage({required this.userModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70.h),
        child: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: colors.appColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20.r),
              bottomRight: Radius.circular(20.r),
            ),
          ),
          title: Text(
            "Emergency Alert",
            style: TextStyle(fontSize: 20.sp, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 100.sp,
                color: Colors.red,
              ),
              SizedBox(height: 30.h),
              Text(
                "Send Emergency Alert",
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              Text(
                "Press the button below to send an emergency alert to your caretaker",
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 50.h),
              SizedBox(
                width: double.infinity,
                height: 60.h,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement emergency alert functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Emergency alert sent to caretaker!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: Text(
                    "SEND ALERT",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
