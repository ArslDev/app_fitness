import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_fitness/view/sleep_tracker/sleep_add_alarm_view.dart';
import 'package:simple_animation_progress_bar/simple_animation_progress_bar.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/today_sleep_schedule_row.dart';

class SleepTrackerView extends StatefulWidget {
  const SleepTrackerView({super.key});

  @override
  State<SleepTrackerView> createState() => _SleepTrackerViewState();
}

class _SleepTrackerViewState extends State<SleepTrackerView> {
  // Persist toggle state for Bedtime and Alarm
  Future<void> _saveToggleState(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('toggle_$key', value);
  }

  Future<bool> _loadToggleState(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('toggle_$key') ?? false;
  }

  Future<void> _scheduleNotification(String type) async {
    final permissionStatus = await Permission.notification.request();
    if (!permissionStatus.isGranted) return;
    tz.initializeTimeZones();
    DateTime? scheduledTime;
    String title = '';
    String body = '';
    if (type == 'Bedtime') {
      scheduledTime = _bedTime;
      title = 'Bedtime Reminder';
      body = 'It\'s time to go to bed!';
    } else if (type == 'Alarm') {
      scheduledTime = _alarmTime;
      title = 'Alarm Reminder';
      body = 'Wake up!';
    }
    if (scheduledTime == null) return;
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: tzTime.year,
        month: tzTime.month,
        day: tzTime.day,
        hour: tzTime.hour,
        minute: tzTime.minute,
        second: 0,
        millisecond: 0,
        repeats: false,
        preciseAlarm: true,
        timeZone: tz.local.name,
      ),
    );
  }

  // Populated from saved schedule (today)
  List todaySleepArr = [];
  DateTime? _bedTime;
  DateTime? _alarmTime;
  Timer? _ticker;

  // Weekly dynamic sleep hours (Sun..Sat => x:1..7)
  List<FlSpot> _weeklySpots = const [
    FlSpot(1, 0),
    FlSpot(2, 0),
    FlSpot(3, 0),
    FlSpot(4, 0),
    FlSpot(5, 0),
    FlSpot(6, 0),
    FlSpot(7, 0),
  ];

  List findEatArr = [
    {
      "name": "Breakfast",
      "image": "assets/img/m_3.png",
      "number": "120+ Foods",
    },
    {"name": "Lunch", "image": "assets/img/m_4.png", "number": "130+ Foods"},
  ];

  List<int> showingTooltipOnSpots = [4];

  @override
  void initState() {
    super.initState();
    _loadToday();
    _loadWeekly();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _loadToday();
      _updateTodaySpot();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final base = _dateKey(now);
      final bedStr = prefs.getString('sleep_bed_$base');
      final alarmStr = prefs.getString('sleep_alarm_$base');
      final durMin = prefs.getInt('sleep_duration_min_$base');
      final repeatStr = prefs.getString('sleep_repeat_$base');
      if (bedStr == null || alarmStr == null || durMin == null) {
        setState(() {
          todaySleepArr = [];
          _bedTime = null;
          _alarmTime = null;
        });
        return;
      }
      final bed = DateTime.parse(bedStr);
      var alarm = DateTime.parse(alarmStr);
      // Adjust alarm to next day if earlier than bed
      if (alarm.isBefore(bed)) alarm = alarm.add(const Duration(days: 1));
      _bedTime = bed;
      _alarmTime = alarm;
      final repeatDays = (repeatStr == null || repeatStr.isEmpty)
          ? <int>[]
          : repeatStr
                .split(',')
                .where((e) => e.isNotEmpty)
                .map((e) => int.tryParse(e) ?? 0)
                .toList();
      String fmt(DateTime dt) {
        int h12 = dt.hour % 12;
        if (h12 == 0) h12 = 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final ap = dt.hour >= 12 ? 'PM' : 'AM';
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${h12.toString().padLeft(2, '0')}:$m $ap';
      }

      String remainingUntil(DateTime target) {
        final diff = target.difference(DateTime.now());
        if (diff.isNegative) return 'passed';
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        return 'in ${h}h ${m}m';
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

      final duration = alarm.difference(bed);
      String durTxt(Duration d) {
        final h = d.inHours;
        final m = d.inMinutes % 60;
        return '${h}h ${m}m';
      }

      // Load toggle states for Bedtime and Alarm
      final bedtimeToggle = await _loadToggleState('Bedtime');
      final alarmToggle = await _loadToggleState('Alarm');
      setState(() {
        todaySleepArr = [
          {
            'name': 'Bedtime',
            'image': 'assets/img/bed.png',
            'time': fmt(bed),
            'duration': remainingUntil(bed),
            'toggle': bedtimeToggle,
          },
          {
            'name': 'Alarm',
            'image': 'assets/img/alaarm.png',
            'time': fmt(alarm),
            'duration':
                '${durTxt(duration)} | ${repeatLabel()} | ${remainingUntil(alarm)}',
            'toggle': alarmToggle,
          },
        ];
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadWeekly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final daysToSubtract = now.weekday % 7; // Sunday ->0
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysToSubtract));
      final List<FlSpot> spots = [];
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final base = _dateKey(day);
        final bedStr = prefs.getString('sleep_bed_$base');
        final alarmStr = prefs.getString('sleep_alarm_$base');
        double hours = 0;
        if (bedStr != null && alarmStr != null) {
          DateTime bed = DateTime.parse(bedStr);
          DateTime alarm = DateTime.parse(alarmStr);
          if (alarm.isBefore(bed)) alarm = alarm.add(const Duration(days: 1));
          Duration diff;
          if (day.year == now.year &&
              day.month == now.month &&
              day.day == now.day) {
            if (DateTime.now().isAfter(bed) && DateTime.now().isBefore(alarm)) {
              diff = DateTime.now().difference(bed);
            } else {
              diff = alarm.difference(bed);
            }
          } else {
            diff = alarm.difference(bed);
          }
          hours = diff.inMinutes / 60.0;
          if (hours < 0) hours = 0;
          if (hours > 12) hours = 12;
        }
        spots.add(
          FlSpot((i + 1).toDouble(), double.parse(hours.toStringAsFixed(2))),
        );
      }
      setState(() {
        _weeklySpots = spots;
      });
    } catch (_) {}
  }

  void _updateTodaySpot() {
    if (_bedTime == null || _alarmTime == null) return;
    final now = DateTime.now();
    DateTime bed = _bedTime!;
    DateTime alarm = _alarmTime!;
    if (alarm.isBefore(bed)) alarm = alarm.add(const Duration(days: 1));
    Duration diff;
    if (now.isAfter(bed) && now.isBefore(alarm)) {
      diff = now.difference(bed);
    } else {
      diff = alarm.difference(bed);
    }
    double hours = diff.inMinutes / 60.0;
    if (hours < 0) hours = 0;
    if (hours > 12) hours = 12;
    final daysToSubtract = now.weekday % 7;
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
    final dayIndex = now.difference(startOfWeek).inDays; // 0..6
    if (dayIndex >= 0 && dayIndex < _weeklySpots.length) {
      final updated = List<FlSpot>.from(_weeklySpots);
      updated[dayIndex] = FlSpot(
        (dayIndex + 1).toDouble(),
        double.parse(hours.toStringAsFixed(2)),
      );
      setState(() {
        _weeklySpots = updated;
      });
    }
  }

  String _lastNightDurationText() {
    if (_bedTime == null || _alarmTime == null) return '--';
    final dur = _alarmTime!.difference(_bedTime!);
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    final tooltipsOnBar = lineBarsData1[0];
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
          "Sleep Tracker",
          style: TextStyle(
            color: TColor.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 15),
                    height: media.width * 0.5,
                    width: double.maxFinite,
                    child: LineChart(
                      LineChartData(
                        showingTooltipIndicators: showingTooltipOnSpots.map((
                          index,
                        ) {
                          return ShowingTooltipIndicators([
                            LineBarSpot(
                              tooltipsOnBar,
                              lineBarsData1.indexOf(tooltipsOnBar),
                              tooltipsOnBar.spots[index],
                            ),
                          ]);
                        }).toList(),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          handleBuiltInTouches: false,
                          touchCallback:
                              (
                                FlTouchEvent event,
                                LineTouchResponse? response,
                              ) {
                                if (response == null ||
                                    response.lineBarSpots == null) {
                                  return;
                                }
                                if (event is FlTapUpEvent) {
                                  final spotIndex =
                                      response.lineBarSpots!.first.spotIndex;
                                  showingTooltipOnSpots.clear();
                                  setState(() {
                                    showingTooltipOnSpots.add(spotIndex);
                                  });
                                }
                              },
                          mouseCursorResolver:
                              (
                                FlTouchEvent event,
                                LineTouchResponse? response,
                              ) {
                                if (response == null ||
                                    response.lineBarSpots == null) {
                                  return SystemMouseCursors.basic;
                                }
                                return SystemMouseCursors.click;
                              },
                          getTouchedSpotIndicator:
                              (
                                LineChartBarData barData,
                                List<int> spotIndexes,
                              ) {
                                return spotIndexes.map((index) {
                                  return TouchedSpotIndicatorData(
                                    FlLine(color: Colors.transparent),
                                    FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                                radius: 3,
                                                color: Colors.white,
                                                strokeWidth: 1,
                                                strokeColor:
                                                    TColor.primaryColor2,
                                              ),
                                    ),
                                  );
                                }).toList();
                              },
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: TColor.secondaryColor1,
                            tooltipRoundedRadius: 5,
                            getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                              return lineBarsSpot.map((lineBarSpot) {
                                return LineTooltipItem(
                                  "${lineBarSpot.y.toInt()} hours",
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: lineBarsData1,
                        minY: -0.01,
                        maxY: 10.01,
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
                          horizontalInterval: 2,
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
                  Container(
                    width: double.maxFinite,
                    height: media.width * 0.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: TColor.primaryG),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            "Last Night Sleep",
                            style: TextStyle(color: TColor.white, fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            _lastNightDurationText(),
                            style: TextStyle(
                              color: TColor.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Image.asset(
                          "assets/img/SleepGraph.png",
                          width: double.maxFinite,
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
                          "Daily Sleep Schedule",
                          style: TextStyle(
                            color: TColor.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: media.width * 0.05),
                  // Sleep Progress Bar (added)
                  Builder(
                    builder: (context) {
                      const int idealSleepMinutes = 8 * 60 + 30; // 8h30m
                      double ratio = 0.0;
                      String label = '0%';
                      if (_bedTime != null && _alarmTime != null) {
                        DateTime bed = _bedTime!;
                        DateTime alarm = _alarmTime!;
                        if (alarm.isBefore(bed)) {
                          alarm = alarm.add(const Duration(days: 1));
                        }
                        final now = DateTime.now();
                        final scheduledMinutes = alarm
                            .difference(bed)
                            .inMinutes;
                        if (now.isBefore(bed)) {
                          ratio = (scheduledMinutes / idealSleepMinutes).clamp(
                            0.0,
                            1.0,
                          );
                        } else if (now.isAfter(alarm)) {
                          ratio = (scheduledMinutes / idealSleepMinutes).clamp(
                            0.0,
                            1.0,
                          );
                        } else {
                          final slept = now.difference(bed).inMinutes;
                          ratio = (slept / idealSleepMinutes).clamp(0.0, 1.0);
                        }
                        label = '${(ratio * 100).toStringAsFixed(0)}%';
                      }
                      return Container(
                        width: double.maxFinite,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              TColor.secondaryColor2.withOpacity(0.35),
                              TColor.secondaryColor1.withOpacity(0.35),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sleep Progress',
                              style: TextStyle(
                                color: TColor.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SimpleAnimationProgressBar(
                                  height: 15,
                                  width: media.width - 80,
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: TColor.primaryColor1,
                                  ratio: ratio,
                                  direction: Axis.horizontal,
                                  curve: Curves.fastLinearToSlowEaseIn,
                                  duration: const Duration(seconds: 1),
                                  borderRadius: BorderRadius.circular(7.5),
                                  gradientColor: LinearGradient(
                                    colors: TColor.secondaryG,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: TColor.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Text(
                    "Today Schedule",
                    style: TextStyle(
                      color: TColor.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: media.width * 0.03),
                  if (todaySleepArr.isNotEmpty)
                    ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: todaySleepArr.length,
                      itemBuilder: (context, index) {
                        var sObj = todaySleepArr[index] as Map? ?? {};
                        final toggleKey = sObj['name'] ?? '';
                        final initialToggle = sObj['toggle'] ?? false;
                        return TodaySleepScheduleRow(
                          sObj: sObj,
                          initialToggle: initialToggle,
                          onToggleChanged: (isOn) async {
                            await _saveToggleState(toggleKey, isOn);
                            setState(() {
                              todaySleepArr[index]['toggle'] = isOn;
                            });
                            if (isOn &&
                                sObj['time'] != '-' &&
                                sObj['time'].toString().trim().isNotEmpty) {
                              await _scheduleNotification(sObj['name']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${sObj['name']} notification scheduled!',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'No sleep schedule set for today. Tap Check to add.',
                        style: TextStyle(color: TColor.gray, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: media.width * 0.2),
          ],
        ),
      ),
      floatingActionButton: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SleepAddAlarmView(date: DateTime.now()),
            ),
          );
          if (result is Map) {
            try {
              final bed = DateTime.parse(result['bedTime']);
              final alarm = DateTime.parse(result['alarmTime']);
              final durationMinutes = result['durationMinutes'] as int? ?? 0;
              final repeatDays =
                  (result['repeatDays'] as List?)?.cast<int>() ?? [];
              final prefs = await SharedPreferences.getInstance();
              final now = DateTime.now();
              final base = _dateKey(now);
              await prefs.setString('sleep_bed_$base', bed.toIso8601String());
              await prefs.setString(
                'sleep_alarm_$base',
                alarm.toIso8601String(),
              );
              await prefs.setInt('sleep_duration_min_$base', durationMinutes);
              await prefs.setString('sleep_repeat_$base', repeatDays.join(','));
              await _loadToday();
              await _loadWeekly();
              _updateTodaySpot();
            } catch (_) {}
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

  List<LineChartBarData> get lineBarsData1 => [lineChartBarDataDynamic];

  LineChartBarData get lineChartBarDataDynamic => LineChartBarData(
    isCurved: true,
    gradient: LinearGradient(
      colors: [TColor.primaryColor2, TColor.primaryColor1],
    ),
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        colors: [TColor.primaryColor2, TColor.white],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    spots: _weeklySpots,
  );

  SideTitles get rightTitles => SideTitles(
    getTitlesWidget: rightTitleWidgets,
    showTitles: true,
    interval: 2,
    reservedSize: 40,
  );

  Widget rightTitleWidgets(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0:
        text = '0h';
        break;
      case 2:
        text = '2h';
        break;
      case 4:
        text = '4h';
        break;
      case 6:
        text = '6h';
        break;
      case 8:
        text = '8h';
        break;
      case 10:
        text = '10h';
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
