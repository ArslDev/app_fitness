import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/setting_row.dart';
import '../../common_widget/title_subtitle_cell.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool positive = false;

  String userName = "";
  String userDob = "";
  double userWeight = 0;
  double userHeight = 0;
  int userAge = 0;
  String userGender = "";

  List accountArr = [
    {"image": "assets/img/p_personal.png", "name": "Personal Data", "tag": "1"},
    {"image": "assets/img/p_achi.png", "name": "Achievement", "tag": "2"},
    {
      "image": "assets/img/p_activity.png",
      "name": "Activity History",
      "tag": "3",
    },
    {
      "image": "assets/img/p_workout.png",
      "name": "Workout Progress",
      "tag": "4",
    },
  ];

  List otherArr = [
    {"image": "assets/img/p_contact.png", "name": "Contact Us", "tag": "5"},
    {"image": "assets/img/p_privacy.png", "name": "Privacy Policy", "tag": "6"},
    {"image": "assets/img/p_setting.png", "name": "Setting", "tag": "7"},
  ];
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "";
      userDob = prefs.getString('user_dob') ?? "";
      userWeight = prefs.getDouble('user_weight') ?? 0;
      userHeight = prefs.getDouble('user_height') ?? 0;
      userAge = _calculateAge(userDob);
      userGender = prefs.getString('user_gender') ?? "";
    });
  }

  Future<void> _saveUserProfile({
    required String name,
    required String dob,
    required double weight,
    required double height,
    required String gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name.trim());
    await prefs.setString('user_dob', dob.trim());
    await prefs.setDouble('user_weight', weight);
    await prefs.setDouble('user_height', height);
    await prefs.setString('user_gender', gender);
    await _loadUserProfile();
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: userName);
    final dobCtrl = TextEditingController(text: userDob); // dd/MM/yyyy
    final weightCtrl = TextEditingController(
      text: userWeight > 0 ? userWeight.toStringAsFixed(1) : '',
    );
    final heightCtrl = TextEditingController(
      text: userHeight > 0 ? userHeight.toStringAsFixed(1) : '',
    );
    String genderLocal = userGender.isNotEmpty ? userGender : 'Male';
    String? nameErr;
    String? dobErr;
    String? weightErr;
    String? heightErr;

    DateTime? _parseDob(String v) {
      try {
        final parts = v.split('/');
        if (parts.length == 3) {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      } catch (_) {}
      return null;
    }

    void validateAll(StateSetter setInner) {
      nameErr = nameCtrl.text.trim().isEmpty ? 'Required' : null;
      final dob = dobCtrl.text.trim();
      final dt = _parseDob(dob);
      if (dob.isEmpty) {
        dobErr = 'Required';
      } else if (dt == null) {
        dobErr = 'Invalid (dd/MM/yyyy)';
      } else if (dt.isAfter(DateTime.now())) {
        dobErr = 'In future';
      } else {
        dobErr = null;
      }
      final w = double.tryParse(weightCtrl.text.trim());
      weightErr = (w == null || w <= 0) ? 'Enter > 0' : null;
      final h = double.tryParse(heightCtrl.text.trim());
      heightErr = (h == null || h <= 0) ? 'Enter > 0' : null;
      setInner(() {});
    }

    Future<void> pickDob(StateSetter setInner) async {
      final now = DateTime.now();
      final initial =
          _parseDob(dobCtrl.text) ??
          DateTime(now.year - 18, now.month, now.day);
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900, 1, 1),
        lastDate: DateTime(now.year, now.month, now.day),
        helpText: 'Select Date of Birth',
      );
      if (picked != null) {
        dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        validateAll(setInner);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInner) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      TColor.primaryColor2.withOpacity(0.92),
                      TColor.primaryColor1.withOpacity(0.92),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: TColor.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: TColor.white),
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Name
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: TColor.white),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(color: Colors.white70),
                          errorText: nameErr,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => validateAll(setInner),
                      ),
                      const SizedBox(height: 12),
                      // DOB
                      TextField(
                        controller: dobCtrl,
                        readOnly: true,
                        style: TextStyle(color: TColor.white),
                        decoration: InputDecoration(
                          labelText: 'Date of Birth (dd/MM/yyyy)',
                          labelStyle: TextStyle(color: Colors.white70),
                          errorText: dobErr,
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 18,
                            ),
                            onPressed: () => pickDob(setInner),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onTap: () => pickDob(setInner),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: TColor.white),
                              decoration: InputDecoration(
                                labelText: 'Weight (kg)',
                                labelStyle: TextStyle(color: Colors.white70),
                                errorText: weightErr,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => validateAll(setInner),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: heightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: TColor.white),
                              decoration: InputDecoration(
                                labelText: 'Height (cm)',
                                labelStyle: TextStyle(color: Colors.white70),
                                errorText: heightErr,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => validateAll(setInner),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gender',
                        style: TextStyle(
                          color: TColor.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: ['Male', 'Female'].map((g) {
                          final selected = genderLocal == g;
                          return ChoiceChip(
                            label: Text(g),
                            selected: selected,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: TColor.primaryColor1.withOpacity(
                              0.6,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.12),
                            onSelected: (_) => setInner(() {
                              genderLocal = g;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                              ).merge(
                                ButtonStyle(
                                  overlayColor: MaterialStateProperty.all(
                                    Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                          onPressed: () async {
                            validateAll(setInner);
                            if (nameErr != null ||
                                dobErr != null ||
                                weightErr != null ||
                                heightErr != null)
                              return;
                            final w =
                                double.tryParse(weightCtrl.text.trim()) ?? 0;
                            final h =
                                double.tryParse(heightCtrl.text.trim()) ?? 0;
                            await _saveUserProfile(
                              name: nameCtrl.text,
                              dob: dobCtrl.text,
                              weight: w,
                              height: h,
                              gender: genderLocal,
                            );
                            if (mounted) Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated'),
                                ),
                              );
                            }
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: TColor.primaryG),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _calculateAge(String dob) {
    if (dob.isEmpty) return 0;
    try {
      final parts = dob.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final birthDate = DateTime(year, month, day);
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        return age;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.white,
        centerTitle: true,
        elevation: 0,
        leadingWidth: 0,
        title: Text(
          "Profile",
          style: TextStyle(
            color: TColor.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      userGender == "Male"
                          ? "assets/img/u1.png"
                          : "assets/img/u2.png",
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName.isNotEmpty ? userName : "User",
                          style: TextStyle(
                            color: TColor.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          userDob.isNotEmpty ? userDob : "No DOB",
                          style: TextStyle(color: TColor.gray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    height: 25,
                    child: RoundButton(
                      title: "Edit",
                      type: RoundButtonType.bgGradient,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      onPressed: _showEditProfileDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TitleSubtitleCell(
                      title: userHeight > 0
                          ? "${userHeight.toStringAsFixed(1)}cm"
                          : "--",
                      subtitle: "Height",
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: TitleSubtitleCell(
                      title: userWeight > 0
                          ? "${userWeight.toStringAsFixed(1)}kg"
                          : "--",
                      subtitle: "Weight",
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: TitleSubtitleCell(
                      title: userAge > 0 ? "${userAge}yo" : "--",
                      subtitle: "Age",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              // Container(
              //   padding: const EdgeInsets.symmetric(
              //     vertical: 10,
              //     horizontal: 15,
              //   ),
              //   decoration: BoxDecoration(
              //     color: TColor.white,
              //     borderRadius: BorderRadius.circular(15),
              //     boxShadow: const [
              //       BoxShadow(color: Colors.black12, blurRadius: 2),
              //     ],
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         "Account",
              //         style: TextStyle(
              //           color: TColor.black,
              //           fontSize: 16,
              //           fontWeight: FontWeight.w700,
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       ListView.builder(
              //         physics: const NeverScrollableScrollPhysics(),
              //         shrinkWrap: true,
              //         itemCount: accountArr.length,
              //         itemBuilder: (context, index) {
              //           var iObj = accountArr[index] as Map? ?? {};
              //           return SettingRow(
              //             icon: iObj["image"].toString(),
              //             title: iObj["name"].toString(),
              //             onPressed: () {},
              //           );
              //         },
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  color: TColor.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Notification",
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/img/p_notification.png",
                            height: 15,
                            width: 15,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              "Pop-up Notification",
                              style: TextStyle(
                                color: TColor.black,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          CustomAnimatedToggleSwitch<bool>(
                            current: positive,
                            values: [false, true],
                            dif: 0.0,
                            indicatorSize: Size.square(30.0),
                            animationDuration: const Duration(
                              milliseconds: 200,
                            ),
                            animationCurve: Curves.linear,
                            onChanged: (b) => setState(() => positive = b),
                            iconBuilder: (context, local, global) {
                              return const SizedBox();
                            },
                            defaultCursor: SystemMouseCursors.click,
                            onTap: () => setState(() => positive = !positive),
                            iconsTappable: false,
                            wrapperBuilder: (context, global, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    left: 10.0,
                                    right: 10.0,

                                    height: 30.0,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: TColor.secondaryG,
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(50.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child,
                                ],
                              );
                            },
                            foregroundIndicatorBuilder: (context, global) {
                              return SizedBox.fromSize(
                                size: const Size(10, 10),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: TColor.white,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(50.0),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        spreadRadius: 0.05,
                                        blurRadius: 1.1,
                                        offset: Offset(0.0, 0.8),
                                      ),
                                    ],
                                  ),
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
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  color: TColor.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Other",
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: otherArr.length,
                      itemBuilder: (context, index) {
                        var iObj = otherArr[index] as Map? ?? {};
                        return SettingRow(
                          icon: iObj["image"].toString(),
                          title: iObj["name"].toString(),
                          onPressed: () {},
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
    );
  }
}
