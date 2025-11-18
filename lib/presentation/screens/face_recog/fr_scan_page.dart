import 'package:cogni_anchor/presentation/constants/colors.dart' as colors;
import 'package:cogni_anchor/presentation/screens/face_recog/fr_result_found_page.dart';
import 'package:cogni_anchor/presentation/widgets/common/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

class FRScanPage extends StatefulWidget {
  const FRScanPage({super.key});

  @override
  State<FRScanPage> createState() => _FRScanPageState();
}

class _FRScanPageState extends State<FRScanPage> {
  
  @override
  void initState() {
    super.initState();
    // Simulate a delay then find a result (Demo purpose)
    Future.delayed(const Duration(seconds: 3), () {
       if (mounted) {
         // Change this to FRResultNotFoundPage() to test the other screen
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FRResultFoundPage()));
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fake Camera Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/face_placeholder.jpg"), // Ensure you have a dummy image or remove this line
                fit: BoxFit.cover,
                opacity: 0.6, // Make it look like a viewfinder
              )
            ),
            child: Container(color: Colors.black26), // Dark overlay if image missing
          ),

          // 2. Top "Trouble remembering" banner
          Positioned(
            top: 60.h,
            left: 0,
            right: 0,
            child: Center(
              child: AppText("Trouble remembering a person?", color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
          ),

          // 3. Scanning Frame Center
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Container(
                  width: 280.w,
                  height: 350.h,
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.appColor, width: 3),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                Gap(20.h),
                // Scanning loader
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  child: Column(
                    children: [
                      Icon(Icons.camera, color: colors.appColor),
                      Gap(5.h),
                      AppText("Scanning face...", fontSize: 12.sp, color: Colors.grey),
                    ],
                  ),
                )
              ],
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: 40.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circleBtn(Icons.flashlight_on_outlined),
                _circleBtn(Icons.image_outlined),
              ],
            ),
          ),
          
          // Back Button
          Positioned(
            top: 50.h,
            left: 20.w,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon) {
    return Container(
      width: 50.w,
      height: 50.w,
      decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white),
    );
  }
}