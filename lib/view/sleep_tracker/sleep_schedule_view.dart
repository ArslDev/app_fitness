import 'dart:async';

import 'package:app_fitness/view/sleep_tracker/sleep_add_alarm_view.dart';
import 'package:calendar_agenda/calendar_agenda.dart';

import 'package:flutter/material.dart';
import 'package:simple_animation_progress_bar/simple_animation_progress_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/today_sleep_schedule_row.dart';

class SleepScheduleView extends StatefulWidget {
  const SleepScheduleView({super.key});

  @override
  State<SleepScheduleView> createState() => _SleepScheduleViewState();
}

class _SleepScheduleViewState extends State<SleepScheduleView> {
  CalendarAgendaController _calendarAgendaControllerAppBar =
      CalendarAgendaController();
  late DateTime _selectedDateAppBBar;

  // Stored schedule for selected date
  DateTime? _bedTimeForSelected;
  DateTime? _alarmTimeForSelected;

  // Ideal target displayed in top card (8h30m)
  static const int _idealSleepMinutes = 8 * 60 + 30; // 510

  Timer? _summaryTicker;

  List todaySleepArr = [
    {
      "name": "Bedtime",
      "image": "assets/img/bed.png",
      "time": "01/06/2023 09:00 PM",
      "duration": "in 6hours 22minutes",
    },
    {
      "name": "Alarm",
      "image": "assets/img/alaarm.png",
      "time": "02/06/2023 05:10 AM",
      "duration": "in 14hours 30minutes",
    },
  ];

  void _applySleepResult(Map data) {
    try {
      final bed = DateTime.parse(data['bedTime']);
      final alarm = DateTime.parse(data['alarmTime']);
      final durationMinutes = data['durationMinutes'] as int? ?? 0;
      final dur = Duration(minutes: durationMinutes);
      final repeatDays = (data['repeatDays'] as List?)?.cast<int>() ?? [];
      _bedTimeForSelected = bed;
      _alarmTimeForSelected = alarm;
      String fmt(DateTime dt) {
        int h12 = dt.hour % 12;
        if (h12 == 0) h12 = 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final ap = dt.hour >= 12 ? 'PM' : 'AM';
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${h12.toString().padLeft(2, '0')}:$m $ap';
      }

      String durTxt(Duration d) {
        final h = d.inHours;
        final m = d.inMinutes % 60;
        return '${h}h ${m}m';
      }

      String repeatLabel() {
        if (repeatDays.isEmpty) return 'Once';
        if (repeatDays.length == 7) return 'Everyday';
        if (repeatDays.length == 5 &&
            repeatDays.toSet().containsAll({0, 1, 2, 3, 4}))
          return 'Mon-Fri';
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return repeatDays.map((i) => names[i]).join(', ');
      }

      String remainingUntil(DateTime dtTarget) {
        final diff = dtTarget.difference(DateTime.now());
        if (diff.isNegative) return 'passed';
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        return 'in ${h}h ${m}m';
      }

      setState(() {
        todaySleepArr[0] = {
          'name': 'Bedtime',
          'image': 'assets/img/bed.png',
          'time': fmt(bed),
          'duration': remainingUntil(bed),
        };
        todaySleepArr[1] = {
          'name': 'Alarm',
          'image': 'assets/img/alaarm.png',
          'time': fmt(alarm),
          'duration':
              '${durTxt(dur)} | ${repeatLabel()} | ${remainingUntil(alarm)}',
        };
      });
      _saveForDate(
        _selectedDateAppBBar,
        bed,
        alarm,
        durationMinutes,
        repeatDays,
      );
    } catch (_) {}
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveForDate(
    DateTime date,
    DateTime bed,
    DateTime alarm,
    int durationMinutes,
    List<int> repeatDays,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base = _dateKey(date);
      await prefs.setString('sleep_bed_$base', bed.toIso8601String());
      await prefs.setString('sleep_alarm_$base', alarm.toIso8601String());
      await prefs.setInt('sleep_duration_min_$base', durationMinutes);
      await prefs.setString('sleep_repeat_$base', repeatDays.join(','));
    } catch (_) {}
  }

  Future<void> _loadForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final base = _dateKey(date);
    final bedStr = prefs.getString('sleep_bed_$base');
    final alarmStr = prefs.getString('sleep_alarm_$base');
    final durMin = prefs.getInt('sleep_duration_min_$base');
    final repeatStr = prefs.getString('sleep_repeat_$base');
    if (bedStr == null || alarmStr == null || durMin == null)
      return; // nothing stored
    try {
      final bed = DateTime.parse(bedStr);
      final alarm = DateTime.parse(alarmStr);
      final durationMinutes = durMin;
      final repeatDays = (repeatStr == null || repeatStr.isEmpty)
          ? <int>[]
          : repeatStr
                .split(',')
                .where((e) => e.isNotEmpty)
                .map((e) => int.tryParse(e) ?? 0)
                .toList();
      _bedTimeForSelected = bed;
      _alarmTimeForSelected = alarm;
      final dur = Duration(minutes: durationMinutes);
      String fmt(DateTime dt) {
        int h12 = dt.hour % 12;
        if (h12 == 0) h12 = 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final ap = dt.hour >= 12 ? 'PM' : 'AM';
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${h12.toString().padLeft(2, '0')}:$m $ap';
      }

      String durTxt(Duration d) {
        final h = d.inHours;
        final m = d.inMinutes % 60;
        return '${h}h ${m}m';
      }

      String repeatLabel() {
        if (repeatDays.isEmpty) return 'Once';
        if (repeatDays.length == 7) return 'Everyday';
        if (repeatDays.length == 5 &&
            repeatDays.toSet().containsAll({0, 1, 2, 3, 4}))
          return 'Mon-Fri';
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return repeatDays.map((i) => names[i]).join(', ');
      }

      String remainingUntil(DateTime dtTarget) {
        final diff = dtTarget.difference(DateTime.now());
        if (diff.isNegative) return 'passed';
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        return 'in ${h}h ${m}m';
      }

      setState(() {
        todaySleepArr[0] = {
          'name': 'Bedtime',
          'image': 'assets/img/bed.png',
          'time': fmt(bed),
          'duration': remainingUntil(bed),
        };
        todaySleepArr[1] = {
          'name': 'Alarm',
          'image': 'assets/img/alaarm.png',
          'time': fmt(alarm),
          'duration':
              '${durTxt(dur)} | ${repeatLabel()} | ${remainingUntil(alarm)}',
        };
      });
    } catch (_) {}
  }

  List<int> showingTooltipOnSpots = [4];

  @override
  void initState() {
    super.initState();
    _selectedDateAppBBar = DateTime.now();
    _loadForDate(_selectedDateAppBBar);
    _startSummaryTicker();
  }

  void _startSummaryTicker() {
    _summaryTicker?.cancel();
    _summaryTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {}); // rebuild to refresh dynamic summary / progress
    });
  }

  @override
  void dispose() {
    _summaryTicker?.cancel();
    super.dispose();
  }

  String _hmText(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '${h}hours';
    if (h == 0) return '${m}minutes';
    return '${h}hours ${m}minutes';
  }

  /// Returns dynamic sleep summary for current time relative to selected schedule.
  /// text: description lines, ratio: progress bar ratio (0-1), percentLabel: formatted percent.
  Map<String, dynamic> _sleepSummaryNow() {
    if (_bedTimeForSelected == null || _alarmTimeForSelected == null) {
      return {
        'text': 'Set your bedtime & alarm',
        'ratio': 0.0,
        'percentLabel': '0%',
      };
    }
    final now = DateTime.now();
    DateTime bed = _bedTimeForSelected!;
    DateTime alarm = _alarmTimeForSelected!;
    // If alarm appears before bed (crosses midnight) treat as next day
    if (alarm.isBefore(bed)) alarm = alarm.add(const Duration(days: 1));
    final scheduledMinutes = alarm.difference(bed).inMinutes;
    final idealRatioFull = scheduledMinutes / _idealSleepMinutes;
    String text;
    double ratio;
    if (now.isBefore(bed)) {
      text = 'You will get ${_hmText(scheduledMinutes)}\nfor tonight';
      ratio = idealRatioFull.clamp(0.0, 1.0);
    } else if (now.isAfter(alarm)) {
      text = 'Completed ${_hmText(scheduledMinutes)} sleep';
      ratio = idealRatioFull.clamp(0.0, 1.0);
    } else {
      // Currently within sleep window -> progress so far toward ideal target
      final sleptMinutes = now.difference(bed).inMinutes;
      final remaining = scheduledMinutes - sleptMinutes;
      text =
          'Sleeping: ${_hmText(sleptMinutes)} done, ${_hmText(remaining)} left';
      ratio = (sleptMinutes / _idealSleepMinutes).clamp(0.0, 1.0);
    }
    final percent = (ratio * 100).toStringAsFixed(0);
    return {'text': text, 'ratio': ratio, 'percentLabel': '$percent%'};
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
              "assets/img/black_btn.png",
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          "Sleep Schedule",
          style: TextStyle(
            color: TColor.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          InkWell(
            onTap: () {},
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
                "assets/img/more_btn.png",
                width: 15,
                height: 15,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  child: Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(20),
                    height: media.width * 0.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TColor.primaryColor2.withOpacity(0.4),
                          TColor.primaryColor1.withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 15),
                            Text(
                              "Ideal Hours for Sleep",
                              style: TextStyle(
                                color: TColor.black,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "8hours 30minutes",
                              style: TextStyle(
                                color: TColor.primaryColor2,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 110,
                              height: 35,
                              child: RoundButton(
                                title: "Learn More",
                                fontSize: 12,
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                        Image.asset(
                          "assets/img/sleep_schedule.png",
                          width: media.width * 0.35,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: media.width * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  child: Text(
                    "Your Schedule",
                    style: TextStyle(
                      color: TColor.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CalendarAgenda(
                  controller: _calendarAgendaControllerAppBar,
                  appbar: false,
                  selectedDayPosition: SelectedDayPosition.center,
                  leading: IconButton(
                    onPressed: () {},
                    icon: Image.asset(
                      "assets/img/ArrowLeft.png",
                      width: 15,
                      height: 15,
                    ),
                  ),
                  // training: IconButton(
                  //     onPressed: () {},
                  //     icon: Image.asset(
                  //       "assets/img/ArrowRight.png",
                  //       width: 15,
                  //       height: 15,
                  //     )),
                  // weekDay: WeekDay.short,
                  // dayNameFontSize: 12,
                  // dayNumberFontSize: 16,
                  // dayBGColor: Colors.grey.withOpacity(0.15),
                  // titleSpaceBetween: 15,
                  backgroundColor: Colors.transparent,
                  // fullCalendar: false,
                  fullCalendarScroll: FullCalendarScroll.horizontal,
                  fullCalendarDay: WeekDay.short,
                  selectedDateColor: TColor.primaryColor2,
                  dateColor: Colors.black,
                  locale: 'en',

                  initialDate: DateTime.now(),
                  calendarEventColor: TColor.primaryColor2,
                  firstDate: DateTime.now().subtract(const Duration(days: 140)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),

                  onDateSelected: (date) {
                    _selectedDateAppBBar = date;
                    _loadForDate(date);
                  },
                  // selectedDayLogo: Container(
                  //   width: double.maxFinite,
                  //   height: double.maxFinite,
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(
                  //         colors: TColor.primaryG,
                  //         begin: Alignment.topCenter,
                  //         end: Alignment.bottomCenter),
                  //     borderRadius: BorderRadius.circular(10.0),
                  //   ),
                  // ),
                ),
                SizedBox(height: media.width * 0.03),
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: todaySleepArr.length,
                  itemBuilder: (context, index) {
                    var sObj = todaySleepArr[index] as Map? ?? {};
                    return TodaySleepScheduleRow(sObj: sObj);
                  },
                ),
                Container(
                  width: double.maxFinite,
                  margin: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TColor.secondaryColor2.withOpacity(0.4),
                        TColor.secondaryColor1.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final summary = _sleepSummaryNow();
                          return Text(
                            summary['text'],
                            style: TextStyle(color: TColor.black, fontSize: 12),
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final summary = _sleepSummaryNow();
                              return SimpleAnimationProgressBar(
                                height: 15,
                                width: media.width - 80,
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: Colors.purple,
                                ratio: summary['ratio'],
                                direction: Axis.horizontal,
                                curve: Curves.fastLinearToSlowEaseIn,
                                duration: const Duration(seconds: 1),
                                borderRadius: BorderRadius.circular(7.5),
                                gradientColor: LinearGradient(
                                  colors: TColor.secondaryG,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final summary = _sleepSummaryNow();
                              return Text(
                                summary['percentLabel'],
                                style: TextStyle(
                                  color: TColor.black,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: media.width * 0.05),
          ],
        ),
      ),
      floatingActionButton: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SleepAddAlarmView(date: _selectedDateAppBBar),
            ),
          );
          if (result is Map) {
            _applySleepResult(result);
          }
        },
        child: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: TColor.secondaryG),
            borderRadius: BorderRadius.circular(27.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add, size: 20, color: TColor.white),
        ),
      ),
    );
  }
}
