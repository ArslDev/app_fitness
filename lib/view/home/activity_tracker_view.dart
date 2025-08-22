import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../common/color_extension.dart';
import '../../common_widget/latest_activity_row.dart';
import '../../common_widget/today_target_cell.dart';

class ActivityTrackerView extends StatefulWidget {
  const ActivityTrackerView({super.key});

  @override
  State<ActivityTrackerView> createState() => _ActivityTrackerViewState();
}

class _ActivityTrackerViewState extends State<ActivityTrackerView> {
  int touchedIndex = -1;
  String _selectedPeriod = 'Weekly';

  // Daily water target in liters (persisted)
  double _dailyWaterTargetLiters = 8.0;
  final String _waterTargetKey = 'daily_water_target_liters';
  // One-time drink amount (ml)
  int _defaultIntakeMl = 250;
  final String _defaultIntakeKey = 'default_intake_ml';

  // Weekly water (Sun-Sat) in liters for bar chart
  List<double> _weeklyWaterLiters = List<double>.filled(7, 0.0);
  List<double> _monthlyWaterLiters = []; // per day liters for current month

  List latestArr = [
    // initial placeholder removed when dynamic data loads
  ];

  Future<void> _deleteIntakeAt(int index) async {
    if (index < 0 || index >= latestArr.length) return;
    // Parse ml amount back to int if possible and remove matching event from storage.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key =
        'water_intakes_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return;
    dynamic decodedRaw;
    try {
      decodedRaw = jsonDecode(jsonStr);
    } catch (_) {
      return;
    }
    if (decodedRaw is! List) return;
    final decoded = List.from(decodedRaw);
    // latestArr built from newest first, we just remove the corresponding entry by relative position in original list.
    // Because we only took the first 10 events, map index to that in decoded (assuming decoded already in newest-first order).
    if (index < decoded.length) {
      decoded.removeAt(index);
      await prefs.setString(key, jsonEncode(decoded));
    }
    setState(() {
      latestArr.removeAt(index);
    });
  }

  Future<void> _loadTodayIntakesForLatest() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key =
        'water_intakes_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final jsonStr = prefs.getString(key);
    List<Map<String, dynamic>> events = [];
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          events = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
    }
    // Build latestArr entries
    final nowMs = DateTime.now();
    List mapList = events.take(10).map((e) {
      final t = DateTime.tryParse(e['time'] ?? '') ?? nowMs;
      final diff = nowMs.difference(t);
      String rel;
      if (diff.inMinutes < 1)
        rel = 'Just now';
      else if (diff.inMinutes < 60)
        rel = '${diff.inMinutes} min ago';
      else if (diff.inHours < 24)
        rel = '${diff.inHours}h ago';
      else
        rel = '${diff.inDays}d ago';
      final ml = e['ml'] ?? 0;
      return {
        'image': 'assets/img/pic_5.png',
        'title': 'Drank ${ml}ml Water',
        'time': rel,
      };
    }).toList();
    setState(() {
      latestArr = mapList;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadWaterTarget();
    _loadWeeklyWater();
    _loadMonthlyWater();
    _loadTodayIntakesForLatest();
  }

  Future<void> _loadWaterTarget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyWaterTargetLiters = prefs.getDouble(_waterTargetKey) ?? 8.0;
      _defaultIntakeMl = prefs.getInt(_defaultIntakeKey) ?? 250;
    });
  }

  Future<void> _loadWeeklyWater() async {
    final prefs = await SharedPreferences.getInstance();
    // Determine Sunday of current week
    final now = DateTime.now();
    final daysToSubtract =
        now.weekday % 7; // Monday=1 .. Sunday=7 -> Sunday => 0
    final sunday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
    List<double> temp = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      final d = sunday.add(Duration(days: i));
      final key =
          'water_consumed_ml_${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final ml = prefs.getInt(key) ?? 0;
      temp[i] = ml / 1000.0; // to liters
    }
    setState(() {
      _weeklyWaterLiters = temp;
    });
  }

  Future<void> _loadMonthlyWater() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    List<double> temp = List.filled(daysInMonth, 0.0);
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(now.year, now.month, day);
      final key =
          'water_consumed_ml_${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final ml = prefs.getInt(key) ?? 0;
      temp[day - 1] = ml / 1000.0;
    }
    setState(() {
      _monthlyWaterLiters = temp;
    });
  }

  double get _weeklyBarMax {
    final maxVal = _weeklyWaterLiters.fold<double>(
      0.0,
      (p, c) => c > p ? c : p,
    );
    final target = _dailyWaterTargetLiters > 0 ? _dailyWaterTargetLiters : 0;
    final base = [
      maxVal,
      target,
      5.0,
    ].reduce((a, b) => a > b ? a : b); // ensure at least 5
    final capped = base > 20 ? 20.0 : (base < 5 ? 5.0 : base);
    return capped.toDouble();
  }

  double get _monthlyBarMax {
    if (_monthlyWaterLiters.isEmpty) return 5.0;
    final maxVal = _monthlyWaterLiters.fold<double>(
      0.0,
      (p, c) => c > p ? c : p,
    );
    final target = _dailyWaterTargetLiters > 0 ? _dailyWaterTargetLiters : 0;
    final base = [maxVal, target, 5.0].reduce((a, b) => a > b ? a : b);
    final capped = base > 20 ? 20.0 : (base < 5 ? 5.0 : base);
    return capped.toDouble();
  }

  double get _currentBarMax =>
      _selectedPeriod == 'Weekly' ? _weeklyBarMax : _monthlyBarMax;

  Future<void> _saveWaterSettings(double liters, int intakeMl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_waterTargetKey, liters);
    await prefs.setInt(_defaultIntakeKey, intakeMl);
    setState(() {
      _dailyWaterTargetLiters = liters;
      _defaultIntakeMl = intakeMl;
    });
    _loadWeeklyWater();
    _loadMonthlyWater();
  }

  void _showWaterTargetDialog() {
    final litersController = TextEditingController(
      text: _dailyWaterTargetLiters.toStringAsFixed(0),
    );
    final intakeController = TextEditingController(
      text: _defaultIntakeMl.toString(),
    );
    String? litersErrorText;
    String? intakeErrorText;

    bool validateLiters(String v) {
      if (v.isEmpty) {
        litersErrorText = 'Required';
      } else {
        final intVal = int.tryParse(v);
        if (intVal == null) {
          litersErrorText = 'Invalid number';
        } else if (intVal < 1 || intVal > 15) {
          litersErrorText = 'Enter 1 - 15';
        } else {
          litersErrorText = null;
        }
      }
      return litersErrorText == null;
    }

    bool validateIntake(String v) {
      if (v.isEmpty) {
        intakeErrorText = 'Required';
      } else {
        final intVal = int.tryParse(v);
        if (intVal == null) {
          intakeErrorText = 'Invalid number';
        } else if (intVal < 50 || intVal > 1000) {
          intakeErrorText = '50 - 1000 ml';
        } else {
          intakeErrorText = null;
        }
      }
      return intakeErrorText == null;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInner) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
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
                      TColor.primaryColor2.withOpacity(0.9),
                      TColor.primaryColor1.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: TColor.primaryG),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/img/water.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daily Water Target',
                        style: TextStyle(
                          color: TColor.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your goal in liters (1 - 15)',
                        style: TextStyle(
                          color: TColor.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      // Liters input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: litersErrorText == null
                                ? Colors.white24
                                : Colors.redAccent,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: litersController,
                                maxLength: 2,
                                style: TextStyle(
                                  color: TColor.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  hintText: '8',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                                onChanged: (v) {
                                  validateLiters(v);
                                  setInner(() {});
                                },
                              ),
                            ),
                            Text(
                              'L',
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (litersErrorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          litersErrorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else
                        const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [6, 8, 10, 12, 15].map((preset) {
                          bool selected =
                              litersController.text == preset.toString();
                          return ChoiceChip(
                            label: Text('${preset}L'),
                            selected: selected,
                            onSelected: (_) {
                              litersController.text = preset.toString();
                              validateLiters(litersController.text);
                              setInner(() {});
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected
                                  ? TColor.primaryColor1
                                  : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected ? Colors.white : Colors.white30,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      // One-time intake amount section
                      Text(
                        'One-time Drink Amount',
                        style: TextStyle(
                          color: TColor.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'How much you usually drink each tap (ml) 50 - 1000',
                        style: TextStyle(
                          color: TColor.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: intakeErrorText == null
                                ? Colors.white24
                                : Colors.redAccent,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: intakeController,
                                maxLength: 4,
                                style: TextStyle(
                                  color: TColor.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  hintText: '250',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                                onChanged: (v) {
                                  validateIntake(v);
                                  setInner(() {});
                                },
                              ),
                            ),
                            Text(
                              'ml',
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (intakeErrorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          intakeErrorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else
                        const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [150, 200, 250, 300, 500].map((preset) {
                          bool selected =
                              intakeController.text == preset.toString();
                          return ChoiceChip(
                            label: Text('${preset}ml'),
                            selected: selected,
                            onSelected: (_) {
                              intakeController.text = preset.toString();
                              validateIntake(intakeController.text);
                              setInner(() {});
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected
                                  ? TColor.primaryColor1
                                  : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected ? Colors.white : Colors.white30,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.white,
                                foregroundColor: TColor.primaryColor1,
                              ),
                              onPressed:
                                  (litersErrorText == null &&
                                      intakeErrorText == null &&
                                      litersController.text.isNotEmpty &&
                                      intakeController.text.isNotEmpty)
                                  ? () {
                                      final liters = int.parse(
                                        litersController.text,
                                      ).toDouble();
                                      final intake = int.parse(
                                        intakeController.text,
                                      );
                                      _saveWaterSettings(liters, intake);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color:
                                      (litersErrorText == null &&
                                          intakeErrorText == null &&
                                          litersController.text.isNotEmpty &&
                                          intakeController.text.isNotEmpty)
                                      ? TColor.primaryColor1
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.white,
        centerTitle: true,
        elevation: 01,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TColor.lightGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              "assets/img/black_btn.png",
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          "Activity Tracker",
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
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TColor.primaryColor2.withOpacity(0.3),
                      TColor.primaryColor1.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
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
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: TColor.primaryG),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: MaterialButton(
                              onPressed: _showWaterTargetDialog, // open dialog
                              padding: EdgeInsets.zero,
                              height: 30,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              textColor: TColor.primaryColor1,
                              minWidth: double.maxFinite,
                              elevation: 0,
                              color: Colors.transparent,
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TodayTargetCell(
                            icon: "assets/img/water.png",
                            value:
                                '${_dailyWaterTargetLiters.toStringAsFixed(1)}L / ${_defaultIntakeMl}ml',
                            title: "Water Target & Tap",
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: media.width * 0.1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Activity  Progress",
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
                                    color: TColor.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        value: _selectedPeriod,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedPeriod = value;
                          });
                          if (value == 'Weekly') {
                            _loadWeeklyWater();
                          } else {
                            _loadMonthlyWater();
                          }
                        },
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
                height: media.width * 0.5,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 0,
                ),
                decoration: BoxDecoration(
                  color: TColor.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 3),
                  ],
                ),
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.grey,
                        tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                        tooltipMargin: 10,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (_selectedPeriod == 'Weekly') {
                            final dayNames = [
                              'Sunday',
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                            ];
                            final liters = _weeklyWaterLiters[group.x];
                            return BarTooltipItem(
                              '${dayNames[group.x]}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '${liters.toStringAsFixed(2)} L',
                                  style: TextStyle(
                                    color: TColor.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            final day = group.x + 1;
                            final liters = group.x < _monthlyWaterLiters.length
                                ? _monthlyWaterLiters[group.x]
                                : 0.0;
                            return BarTooltipItem(
                              'Day $day\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '${liters.toStringAsFixed(2)} L',
                                  style: TextStyle(
                                    color: TColor.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              barTouchResponse == null ||
                              barTouchResponse.spot == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex =
                              barTouchResponse.spot!.touchedBarGroupIndex;
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: _buildBottomTitle,
                          reservedSize: 38,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _selectedPeriod == 'Weekly'
                        ? _weeklyBarGroups()
                        : _monthlyBarGroups(),
                    gridData: FlGridData(show: false),
                  ),
                ),
              ),

              SizedBox(height: media.width * 0.05),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    latestArr.isEmpty ? "No Water Logged" : "Today's Water Log",
                    style: TextStyle(
                      color: TColor.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadTodayIntakesForLatest,
                    child: Text(
                      "Refresh",
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
                itemCount: latestArr.length,
                itemBuilder: (context, index) {
                  var wObj = latestArr[index] as Map? ?? {};
                  return LatestActivityRow(
                    wObj: wObj,
                    onDelete: () => _deleteIntakeAt(index),
                  );
                },
              ),
              SizedBox(height: media.width * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTitle(double value, TitleMeta meta) {
    if (_selectedPeriod == 'Weekly') {
      const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final idx = value.toInt();
      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 8,
        child: Text(
          labels[idx],
          style: TextStyle(color: TColor.gray, fontSize: 12),
        ),
      );
    } else {
      final dayIndex = value.toInt();
      if (dayIndex < 0 || dayIndex >= _monthlyWaterLiters.length)
        return const SizedBox.shrink();
      // Show every 3rd day and always first/last for readability
      if (dayIndex != 0 &&
          dayIndex != _monthlyWaterLiters.length - 1 &&
          dayIndex % 3 != 0)
        return const SizedBox.shrink();
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 6,
        child: Text(
          '${dayIndex + 1}',
          style: TextStyle(color: TColor.gray, fontSize: 10),
        ),
      );
    }
  }

  List<BarChartGroupData> _weeklyBarGroups() => List.generate(7, (i) {
    final y = _weeklyWaterLiters[i];
    final isTouched = i == touchedIndex;
    final gradients = i % 2 == 0 ? TColor.primaryG : TColor.secondaryG;
    return BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: isTouched ? (y + (y * 0.05 + 0.2)) : y,
          gradient: LinearGradient(
            colors: gradients,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          width: 18,
          borderSide: isTouched
              ? const BorderSide(color: Colors.green)
              : const BorderSide(color: Colors.white, width: 0),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: _currentBarMax,
            color: TColor.lightGray,
          ),
        ),
      ],
      showingTooltipIndicators: isTouched ? [0] : [],
    );
  });

  List<BarChartGroupData> _monthlyBarGroups() =>
      List.generate(_monthlyWaterLiters.length, (i) {
        final y = _monthlyWaterLiters[i];
        final isTouched = i == touchedIndex;
        final gradients = (i % 2 == 0) ? TColor.primaryG : TColor.secondaryG;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: isTouched ? (y + (y * 0.05 + 0.05)) : y,
              gradient: LinearGradient(
                colors: gradients,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              width: 8,
              borderSide: isTouched
                  ? const BorderSide(color: Colors.green)
                  : const BorderSide(color: Colors.white, width: 0),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _currentBarMax,
                color: TColor.lightGray,
              ),
            ),
          ],
          showingTooltipIndicators: isTouched ? [0] : [],
        );
      });
}
