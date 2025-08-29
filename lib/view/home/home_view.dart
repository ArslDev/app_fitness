import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:simple_animation_progress_bar/simple_animation_progress_bar.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/workout_row.dart';
import 'activity_tracker_view.dart';
import 'finished_workout_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String userName = "";
  String userDob = "";
  double userWeight = 0;
  double userHeight = 0;
  double userBMI = 0;
  String bmiStatus = "";

  // Sleep summary (today)
  Duration? _todaySleepDuration; // scheduled or actual if in progress
  Timer? _sleepTicker;

  List lastWorkoutArr = [
    {
      "name": "Full Body Workout",
      "image": "assets/img/Workout1.png",
      "kcal": "180",
      "time": "20",
      "progress": 0.3,
    },
    {
      "name": "Lower Body Workout",
      "image": "assets/img/Workout2.png",
      "kcal": "200",
      "time": "30",
      "progress": 0.4,
    },
    {
      "name": "Ab Workout",
      "image": "assets/img/Workout3.png",
      "kcal": "300",
      "time": "40",
      "progress": 0.7,
    },
  ];

  List waterArr = [
    {"title": "6am - 8am", "subtitle": "600ml"},
    {"title": "9am - 11am", "subtitle": "500ml"},
    {"title": "11am - 2pm", "subtitle": "1000ml"},
    {"title": "2pm - 4pm", "subtitle": "700ml"},
    {"title": "4pm - now", "subtitle": "900ml"},
  ];

  // Water tracking state & keys
  static const String _waterTargetKey = 'daily_water_target_liters';
  static const String _defaultIntakeKey = 'default_intake_ml';
  double _dailyWaterTargetLiters = 0; // liters
  int _consumedMlToday = 0; // ml
  int _selectedIntakeMl = 250; // ml for add button
  List<Map<String, dynamic>> _intakeEvents = []; // recent events

  String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadWaterData() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyWaterTargetLiters = prefs.getDouble(_waterTargetKey) ?? 0;
    _selectedIntakeMl = prefs.getInt(_defaultIntakeKey) ?? 250;
    final k = _todayKey();
    _consumedMlToday = prefs.getInt('water_consumed_ml_$k') ?? 0;
    final eventsJson = prefs.getString('water_intakes_$k');
    if (eventsJson != null) {
      try {
        final list = jsonDecode(eventsJson);
        if (list is List) {
          _intakeEvents = list
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        _intakeEvents = [];
      }
    } else {
      _intakeEvents = [];
    }
    setState(() {});
  }

  Future<void> _addWaterIntake(int ml) async {
    if (ml <= 0) return;
    if (_dailyWaterTargetLiters <= 0) return; // no target set

    final int targetMl = (_dailyWaterTargetLiters * 1000).round();
    final int remainingMl = targetMl - _consumedMlToday;

    if (remainingMl <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily water target completed')),
      );
      return;
    }

    if (ml > remainingMl) {
      ml = remainingMl; // cap so we never exceed target
    }

    final prefs = await SharedPreferences.getInstance();
    final k = _todayKey();
    _consumedMlToday += ml;
    _intakeEvents.insert(0, {
      'time': DateTime.now().toIso8601String(),
      'ml': ml,
    });
    if (_intakeEvents.length > 30) _intakeEvents = _intakeEvents.sublist(0, 30);
    await prefs.setInt('water_consumed_ml_$k', _consumedMlToday);
    await prefs.setString('water_intakes_$k', jsonEncode(_intakeEvents));
    setState(() {});
  }

  double get _waterProgress => (_dailyWaterTargetLiters > 0)
      ? (_consumedMlToday / 1000.0) / _dailyWaterTargetLiters
      : 0;

  String get _waterHeadline => _dailyWaterTargetLiters > 0
      ? '${(_consumedMlToday / 1000).toStringAsFixed(2)} / ${_dailyWaterTargetLiters.toStringAsFixed(1)} L'
      : '${(_consumedMlToday / 1000).toStringAsFixed(2)} L';

  String get _waterSub => _dailyWaterTargetLiters <= 0
      ? 'Set your daily target'
      : (_waterProgress >= 1
            ? 'Goal reached'
            : '${(_dailyWaterTargetLiters - (_consumedMlToday / 1000)).toStringAsFixed(2)} L left');

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadWaterData();
    _loadTodaySleep();
    _sleepTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadTodaySleep(refreshOnly: true);
    });
  }

  double _calculateBMI(double weight, double heightCm) {
    if (weight > 0 && heightCm > 0) {
      double heightM = heightCm / 100.0;
      return double.parse((weight / (heightM * heightM)).toStringAsFixed(1));
    }
    return 0;
  }

  String _getBMIStatus(double bmi) {
    if (bmi == 0) return "Enter your data";
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal weight";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "";
      userDob = prefs.getString('user_dob') ?? "";
      userWeight = prefs.getDouble('user_weight') ?? 0;
      userHeight = prefs.getDouble('user_height') ?? 0;
      userBMI = _calculateBMI(userWeight, userHeight);
      bmiStatus = _getBMIStatus(userBMI);
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadTodaySleep({bool refreshOnly = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final base = _dateKey(now);
      final bedStr = prefs.getString('sleep_bed_$base');
      final alarmStr = prefs.getString('sleep_alarm_$base');
      if (bedStr == null || alarmStr == null) {
        if (!refreshOnly) {
          setState(() {
            _todaySleepDuration = null;
          });
        }
        return;
      }
      DateTime bed = DateTime.parse(bedStr);
      DateTime alarm = DateTime.parse(alarmStr);
      if (alarm.isBefore(bed)) alarm = alarm.add(const Duration(days: 1));
      Duration dur;
      if (now.isAfter(bed) && now.isBefore(alarm)) {
        // partial so far
        dur = now.difference(bed);
      } else {
        dur = alarm.difference(bed);
      }
      setState(() {
        _todaySleepDuration = dur;
      });
    } catch (_) {}
  }

  String _sleepDurationText() {
    if (_todaySleepDuration == null) return '--';
    final h = _todaySleepDuration!.inHours;
    final m = _todaySleepDuration!.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  void dispose() {
    _sleepTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back,",
                          style: TextStyle(color: TColor.gray, fontSize: 12),
                        ),
                        Text(
                          userName.isNotEmpty ? userName : "User",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: media.width * 0.05),
                Container(
                  height: media.width * 0.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: TColor.primaryG),
                    borderRadius: BorderRadius.circular(media.width * 0.075),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        "assets/img/bg_dots.png",
                        height: media.width * 0.4,
                        width: media.width,
                        fit: BoxFit.fitHeight,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 25,
                          horizontal: 25,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "BMI (Body Mass Index)",
                                  style: TextStyle(
                                    color: TColor.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  userBMI > 0 ? "${userBMI.toString()}" : "--",
                                  style: TextStyle(
                                    color: TColor.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  bmiStatus,
                                  style: TextStyle(
                                    color: TColor.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: media.width * 0.05),
                              ],
                            ),
                            AspectRatio(
                              aspectRatio: 1,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (
                                          FlTouchEvent event,
                                          pieTouchResponse,
                                        ) {},
                                  ),
                                  startDegreeOffset: 250,
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 1,
                                  centerSpaceRadius: 0,
                                  sections: _bmiSections(), // dynamic sections
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: media.width * 0.05),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: TColor.primaryColor2.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today Target",
                        style: TextStyle(
                          color: TColor.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        height: 25,
                        child: RoundButton(
                          title: "Check",
                          type: RoundButtonType.bgGradient,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ActivityTrackerView(),
                              ),
                            ).then((_) => _loadWaterData());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: media.width * 0.05),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: media.width * 0.95,
                        width: media.width,
                        padding: const EdgeInsets.symmetric(
                          vertical: 25,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 2),
                          ],
                        ),
                        child: Row(
                          children: [
                            SimpleAnimationProgressBar(
                              height: media.width * 0.78,
                              width: media.width * 0.07,
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.purple,
                              ratio: _waterProgress.clamp(0, 1),
                              direction: Axis.vertical,
                              curve: Curves.fastLinearToSlowEaseIn,
                              duration: const Duration(seconds: 2),
                              borderRadius: BorderRadius.circular(15),
                              gradientColor: LinearGradient(
                                colors: _waterProgress >= 1
                                    ? [Colors.teal, Colors.greenAccent]
                                    : TColor.primaryG,
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Water Intake',
                                    style: TextStyle(
                                      color: TColor.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (b) =>
                                        LinearGradient(
                                          colors: TColor.primaryG,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ).createShader(
                                          Rect.fromLTWH(
                                            0,
                                            0,
                                            b.width,
                                            b.height,
                                          ),
                                        ),
                                    child: Text(
                                      _waterHeadline,
                                      style: TextStyle(
                                        color: TColor.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _waterSub,
                                    style: TextStyle(
                                      color: TColor.gray,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Column(
                                      children: [
                                        GestureDetector(
                                          onTap: _dailyWaterTargetLiters <= 0
                                              ? null // no target set
                                              : () => _addWaterIntake(
                                                  _selectedIntakeMl,
                                                ),
                                          child: Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: _waterProgress >= 1
                                                    ? [
                                                        Colors.teal,
                                                        Colors.greenAccent,
                                                      ]
                                                    : TColor.primaryG,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _dailyWaterTargetLiters <= 0
                                              ? 'Set target first'
                                              : '+${_selectedIntakeMl} ml each tap',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: TColor.gray,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_intakeEvents
                                      .isNotEmpty) // removed display as per request
                                    const SizedBox.shrink(),
                                  // Timing list removed per request
                                  const SizedBox(height: 4),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Image.asset(
                                      'assets/img/w1.png',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: media.width * 0.05),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: media.width,
                            height: media.width * 0.45,
                            padding: const EdgeInsets.symmetric(
                              vertical: 25,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 2),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Sleep",
                                  style: TextStyle(
                                    color: TColor.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: TColor.primaryG,
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(
                                      Rect.fromLTRB(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _sleepDurationText(),
                                    style: TextStyle(
                                      color: TColor.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                // Use Expanded for image to avoid overflow!
                                Expanded(
                                  child: Image.asset(
                                    "assets/img/sleep_grap.png",
                                    width: media.width,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: media.width * 0.05),
                          Container(
                            width: media.width,
                            height: media.width * 0.45,
                            padding: const EdgeInsets.symmetric(
                              vertical: 25,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 2),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Calories",
                                  style: TextStyle(
                                    color: TColor.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: TColor.primaryG,
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(
                                      Rect.fromLTRB(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "760 kCal",
                                    style: TextStyle(
                                      color: TColor.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                // Use Expanded for chart/stack if needed to avoid overflow
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: media.width * 0.2,
                                      height: media.width * 0.2,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: media.width * 0.15,
                                            height: media.width * 0.15,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: TColor.primaryG,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    media.width * 0.075,
                                                  ),
                                            ),
                                            child: FittedBox(
                                              child: Text(
                                                "230kCal\nleft",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: TColor.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SimpleCircularProgressBar(
                                            progressStrokeWidth: 10,
                                            backStrokeWidth: 10,
                                            progressColors: TColor.primaryG,
                                            backColor: Colors.grey.shade100,
                                            valueNotifier: ValueNotifier(50),
                                            startAngle: -180,
                                          ),
                                        ],
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
                  ],
                ),
                SizedBox(height: media.width * 0.1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Workout Progress",
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: TColor.primaryG),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton(
                          items: ["Weekly", "Monthly"]
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
                          onChanged: (value) {},
                          icon: Icon(Icons.expand_more, color: TColor.white),
                          hint: Text(
                            "Weekly",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: TColor.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: media.width * 0.05),
                Container(
                  padding: const EdgeInsets.only(left: 15),
                  height: media.width * 0.5,
                  width: media.width,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: lineBarsData1,
                      minY: -0.5,
                      maxY: 110,
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: AxisTitles(),
                        topTitles: AxisTitles(),
                        bottomTitles: AxisTitles(sideTitles: bottomTitles),
                        rightTitles: AxisTitles(sideTitles: rightTitles),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        horizontalInterval: 25,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: TColor.gray.withOpacity(0.15),
                            strokeWidth: 2,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: media.width * 0.05),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Latest Workout",
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "See More",
                        style: TextStyle(
                          color: TColor.gray,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: lastWorkoutArr.length,
                  itemBuilder: (context, index) {
                    var wObj = lastWorkoutArr[index] as Map? ?? {};
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FinishedWorkoutView(),
                          ),
                        );
                      },
                      child: WorkoutRow(wObj: wObj),
                    );
                  },
                ),
                SizedBox(height: media.width * 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Replace old static showingSections with dynamic BMI sections
  List<PieChartSectionData> _bmiSections() {
    if (userBMI == 0) {
      return [
        PieChartSectionData(
          color: Colors.white.withOpacity(0.15),
          value: 1,
          title: '',
          radius: 52,
        ),
      ];
    }

    final categories = [
      {
        'label': 'Under',
        'range': '<18.5',
        'color': Colors.blueAccent,
        'min': 0.0,
        'max': 18.5,
      },
      {
        'label': 'Normal',
        'range': '18.5-24.9',
        'color': Colors.green,
        'min': 18.5,
        'max': 24.9,
      },
      {
        'label': 'Over',
        'range': '25-29.9',
        'color': Colors.orange,
        'min': 24.9,
        'max': 29.9,
      },
      {
        'label': 'Obese',
        'range': '30+',
        'color': Colors.red,
        'min': 29.9,
        'max': 100.0,
      },
    ];

    final bmi = userBMI;

    return categories.map((cat) {
      final bool active =
          bmi >= (cat['min'] as double) && bmi < (cat['max'] as double);
      final baseColor = cat['color'] as Color;
      return PieChartSectionData(
        color: active ? baseColor : baseColor.withOpacity(0.28),
        value: 1,
        title: '',
        radius: active ? 58 : 48,
        badgeWidget: active
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bmi.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    cat['label'] as String,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : null,
        badgePositionPercentageOffset: 0.7,
      );
    }).toList();
  }

  LineTouchData get lineTouchData1 => LineTouchData(
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(
      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
    ),
  );

  List<LineChartBarData> get lineBarsData1 => [
    lineChartBarData1_1,
    lineChartBarData1_2,
  ];

  LineChartBarData get lineChartBarData1_1 => LineChartBarData(
    isCurved: true,
    gradient: LinearGradient(
      colors: [
        TColor.primaryColor2.withOpacity(0.5),
        TColor.primaryColor1.withOpacity(0.5),
      ],
    ),
    barWidth: 4,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(show: false),
    spots: const [
      FlSpot(1, 35),
      FlSpot(2, 70),
      FlSpot(3, 40),
      FlSpot(4, 80),
      FlSpot(5, 25),
      FlSpot(6, 70),
      FlSpot(7, 35),
    ],
  );

  LineChartBarData get lineChartBarData1_2 => LineChartBarData(
    isCurved: true,
    gradient: LinearGradient(
      colors: [
        TColor.secondaryColor2.withOpacity(0.5),
        TColor.secondaryColor1.withOpacity(0.5),
      ],
    ),
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(show: false),
    spots: const [
      FlSpot(1, 80),
      FlSpot(2, 50),
      FlSpot(3, 90),
      FlSpot(4, 40),
      FlSpot(5, 80),
      FlSpot(6, 35),
      FlSpot(7, 60),
    ],
  );

  SideTitles get rightTitles => SideTitles(
    getTitlesWidget: rightTitleWidgets,
    showTitles: true,
    interval: 20,
    reservedSize: 40,
  );

  Widget rightTitleWidgets(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0:
        text = '0%';
        break;
      case 20:
        text = '20%';
        break;
      case 40:
        text = '40%';
        break;
      case 60:
        text = '60%';
        break;
      case 80:
        text = '80%';
        break;
      case 100:
        text = '100%';
        break;
      default:
        return Container();
    }

    return Text(
      text,
      style: TextStyle(color: TColor.gray, fontSize: 12),
      textAlign: TextAlign.center,
    );
  }

  SideTitles get bottomTitles => SideTitles(
    showTitles: true,
    reservedSize: 32,
    interval: 1,
    getTitlesWidget: bottomTitleWidgets,
  );

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    var style = TextStyle(color: TColor.gray, fontSize: 12);
    Widget text;
    switch (value.toInt()) {
      case 1:
        text = Text('Sun', style: style);
        break;
      case 2:
        text = Text('Mon', style: style);
        break;
      case 3:
        text = Text('Tue', style: style);
        break;
      case 4:
        text = Text('Wed', style: style);
        break;
      case 5:
        text = Text('Thu', style: style);
        break;
      case 6:
        text = Text('Fri', style: style);
        break;
      case 7:
        text = Text('Sat', style: style);
        break;
      default:
        text = const Text('');
        break;
    }

    return SideTitleWidget(axisSide: meta.axisSide, space: 10, child: text);
  }
}
