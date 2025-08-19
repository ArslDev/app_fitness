import 'package:app_fitness/view/login/what_your_goal_view.dart';
import 'package:flutter/material.dart';

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/round_textfield.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompleteProfileView extends StatefulWidget {
  const CompleteProfileView({super.key});

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  TextEditingController txtName = TextEditingController();
  TextEditingController txtDate = TextEditingController();
  TextEditingController txtWeight = TextEditingController();
  TextEditingController txtHeight = TextEditingController();

  String selectedGender = '';
  double? selectedWeight;
  double? selectedHeight;
  bool showErrorSplash = false;

  @override
  void initState() {
    super.initState();
    txtWeight.addListener(() {
      setState(() {
        selectedWeight = double.tryParse(txtWeight.text);
      });
    });
    txtHeight.addListener(() {
      setState(() {
        selectedHeight = double.tryParse(txtHeight.text);
      });
    });
  }

  @override
  void dispose() {
    txtName.dispose();
    txtDate.dispose();
    txtWeight.dispose();
    txtHeight.dispose();
    super.dispose();
  }

  // Helper method to show a splash bar with an error message
  void showSplashBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(message, style: TextStyle(color: Colors.white)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Image.asset(
                  "assets/img/complete_profile.png",
                  width: media.width,
                  fit: BoxFit.fitWidth,
                ),
                SizedBox(height: media.width * 0.05),
                Text(
                  "Let’s complete your profile",
                  style: TextStyle(
                    color: TColor.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "It will help us to know more about you!",
                  style: TextStyle(color: TColor.gray, fontSize: 12),
                ),
                SizedBox(height: media.width * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      // Name field
                      RoundTextField(
                        controller: txtName,
                        hitText: "Your Name",
                        icon: "assets/img/profile_tab.png",
                      ),
                      SizedBox(height: media.width * 0.04),
                      Container(
                        decoration: BoxDecoration(
                          color: TColor.lightGray,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Container(
                              alignment: Alignment.center,
                              width: 50,
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Image.asset(
                                "assets/img/gender.png",
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                color: TColor.gray,
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedGender.isEmpty
                                      ? null
                                      : selectedGender,
                                  items: ["Male", "Female"]
                                      .map(
                                        (name) => DropdownMenuItem(
                                          value: name,
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              color: TColor.gray,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedGender = value ?? '';
                                    });
                                  },
                                  isExpanded: true,
                                  hint: Text(
                                    "Choose Gender",
                                    style: TextStyle(
                                      color: TColor.gray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      SizedBox(height: media.width * 0.04),
                      GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            txtDate.text =
                                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                          }
                        },
                        child: AbsorbPointer(
                          child: RoundTextField(
                            controller: txtDate,
                            hitText: "Date of Birth",
                            icon: "assets/img/date.png",
                          ),
                        ),
                      ),
                      SizedBox(height: media.width * 0.04),
                      Row(
                        children: [
                          Expanded(
                            child: RoundTextField(
                              controller: txtWeight,
                              hitText: "Your Weight",
                              icon: "assets/img/weight.png",
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: TColor.secondaryG,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              selectedWeight != null && selectedWeight! > 0
                                  ? "${selectedWeight!.toStringAsFixed(1)} KG"
                                  : "KG",
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: media.width * 0.04),
                      Row(
                        children: [
                          Expanded(
                            child: RoundTextField(
                              controller: txtHeight,
                              hitText: "Your Height",
                              icon: "assets/img/hight.png",
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: TColor.secondaryG,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              selectedHeight != null && selectedHeight! > 0
                                  ? "${selectedHeight!.toStringAsFixed(1)} CM"
                                  : "CM",
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: media.width * 0.07),
                      RoundButton(
                        title: "Next >",
                        onPressed: () async {
                          if (txtName.text.isEmpty ||
                              selectedGender.isEmpty ||
                              txtDate.text.isEmpty ||
                              txtWeight.text.isEmpty ||
                              txtHeight.text.isEmpty) {
                            showSplashBar("Please complete all fields!");
                            return;
                          }
                          // Save user data to shared preferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_name', txtName.text);
                          await prefs.setString('user_gender', selectedGender);
                          await prefs.setString('user_dob', txtDate.text);
                          await prefs.setDouble(
                            'user_weight',
                            double.tryParse(txtWeight.text) ?? 0,
                          );
                          await prefs.setDouble(
                            'user_height',
                            double.tryParse(txtHeight.text) ?? 0,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WhatYourGoalView(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
