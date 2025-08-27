import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/color_extension.dart';
import '../../common/common.dart';
import '../../common_widget/icon_title_next_row.dart';
import '../../common_widget/round_button.dart';

class AddScheduleView extends StatefulWidget {
  final DateTime date;
  final String? workoutName; // optional preselected workout name
  final DateTime?
  initialDateTime; // optional preselected time (existing schedule)
  const AddScheduleView({
    super.key,
    required this.date,
    this.workoutName,
    this.initialDateTime,
  });

  @override
  State<AddScheduleView> createState() => _AddScheduleViewState();
}

class _AddScheduleViewState extends State<AddScheduleView> {
  DateTime? _selectedDateTime; // full date + time for schedule
  String _selectedWorkout = 'Fullbody Workout';

  // Difficulty fixed (UI removed per request); still stored for compatibility.
  String _difficulty = 'Beginner';

  final List<String> _workouts = [
    'Fullbody Workout',
    'Upperbody Workout',
    'Lowerbody Workout',
    'Ab Workout',
  ];

  @override
  void initState() {
    super.initState();
    // If a workout name was provided from the detail screen, preselect it.
    if (widget.workoutName != null && widget.workoutName!.trim().isNotEmpty) {
      _selectedWorkout = widget.workoutName!;
      // Ensure it exists in the picker list so the checkmark shows.
      if (!_workouts.contains(_selectedWorkout)) {
        _workouts.insert(0, _selectedWorkout);
      }
    }

    // Default time = existing schedule (if provided) else now with provided date's Y/M/D
    final base = widget.initialDateTime ?? DateTime.now();
    _selectedDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      base.hour,
      base.minute,
    );
  }

  Future<void> _pickWorkout() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Workout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._workouts.map(
                (w) => ListTile(
                  title: Text(w),
                  trailing: w == _selectedWorkout
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setState(() => _selectedWorkout = w);
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveSchedule() async {
    if (_selectedDateTime == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('workout_schedules');
    List list = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    // Remove any existing schedule entries for this workout (treating name case-insensitively)
    final targetName = _selectedWorkout.trim().toLowerCase();
    list = list.where((e) {
      if (e is Map &&
          (e['name'] ?? '').toString().trim().toLowerCase() == targetName) {
        return false; // drop old
      }
      return true;
    }).toList();

    list.add({
      'name': _selectedWorkout,
      'ts': _selectedDateTime!.toIso8601String(),
      'difficulty': _difficulty,
    });
    await prefs.setString('workout_schedules', jsonEncode(list));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.white,
        centerTitle: true,
        elevation: 0,
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
              "assets/img/closed_btn.png",
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          "Add Schedule",
          style: TextStyle(
            color: TColor.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: TColor.white,
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset("assets/img/date.png", width: 20, height: 20),
                const SizedBox(width: 8),
                Text(
                  dateToString(widget.date, formatStr: "E, dd MMMM yyyy"),
                  style: TextStyle(color: TColor.gray, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Time",
              style: TextStyle(
                color: TColor.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              height: media.width * 0.35,
              child: CupertinoDatePicker(
                onDateTimeChanged: (newTime) {
                  setState(() {
                    _selectedDateTime = DateTime(
                      widget.date.year,
                      widget.date.month,
                      widget.date.day,
                      newTime.hour,
                      newTime.minute,
                    );
                  });
                },
                initialDateTime: _selectedDateTime,
                use24hFormat: false,
                minuteInterval: 1,
                mode: CupertinoDatePickerMode.time,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Details Workout",
              style: TextStyle(
                color: TColor.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            IconTitleNextRow(
              icon: "assets/img/choose_workout.png",
              title: "Choose Workout",
              time: _selectedWorkout,
              color: TColor.lightGray,
              onPressed: _pickWorkout,
            ),
            const SizedBox(height: 10),
            const Spacer(),
            RoundButton(title: "Save", onPressed: _saveSchedule),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
