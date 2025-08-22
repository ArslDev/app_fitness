import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../common/color_extension.dart';

import '../../common_widget/icon_title_next_row.dart';
import '../../common_widget/round_button.dart';

class SleepAddAlarmView extends StatefulWidget {
  final DateTime date;
  const SleepAddAlarmView({super.key, required this.date});

  @override
  State<SleepAddAlarmView> createState() => _SleepAddAlarmViewState();
}

class _SleepAddAlarmViewState extends State<SleepAddAlarmView> {
  bool positive = false;
  DateTime? _bedTime; // selected bedtime
  DateTime? _wakeTime; // selected wake (alarm) time
  int _sleepHours = 8;
  int _sleepMinutes = 0;
  List<bool> _repeat = List<bool>.filled(7, false); // Mon..Sun

  String get _bedTimeLabel =>
      _bedTime == null ? "Select" : _formatTime(_bedTime!);
  String get _durationLabel {
    if (_sleepHours == 0 && _sleepMinutes == 0) return "Select";
    final h = _sleepHours > 0 ? "${_sleepHours}h" : "";
    final m = _sleepMinutes > 0 ? " ${_sleepMinutes}m" : "";
    return (h + m).trim();
  }

  String get _repeatLabel {
    final any = _repeat.contains(true);
    if (!any) return "Once";
    if (_repeat.every((e) => e)) return "Everyday";
    // Mon-Fri shortcut
    if (_repeat.sublist(0, 5).every((e) => e) && !_repeat[5] && !_repeat[6])
      return "Mon-Fri";
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sel = <String>[];
    for (int i = 0; i < 7; i++) {
      if (_repeat[i]) sel.add(names[i]);
    }
    return sel.join(', ');
  }

  String get _wakeTimeLabel =>
      _wakeTime == null ? "Select" : _formatTime(_wakeTime!);
  bool get _hasDuration => _sleepHours != 0 || _sleepMinutes != 0;
  bool get _canSubmit =>
      _bedTime != null && (_wakeTime != null || _hasDuration);

  String _formatTime(DateTime dt) {
    int h12 = dt.hour % 12;
    if (h12 == 0) h12 = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '${h12.toString().padLeft(2, '0')}:$m $ap';
  }

  Future<void> _pickBedTime() async {
    final now = DateTime.now();
    final initial =
        _bedTime ??
        DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          now.hour,
          now.minute,
        );
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked != null) {
      setState(() {
        _bedTime = DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          picked.hour,
          picked.minute,
        );
        if (_hasDuration) {
          _recalcWakeFromBedAndDuration();
        } else if (_wakeTime != null) {
          _recalcDurationFromBedAndWake();
        }
      });
    }
  }

  Future<void> _pickWakeTime() async {
    final base = _wakeTime ?? _bedTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked != null) {
      setState(() {
        // base day is selected date; if before bedtime, assume next day
        DateTime candidate = DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          picked.hour,
          picked.minute,
        );
        if (_bedTime != null && candidate.isBefore(_bedTime!)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        _wakeTime = candidate;
        if (_bedTime != null) {
          _recalcDurationFromBedAndWake();
        }
      });
    }
  }

  Future<void> _pickDuration() async {
    int tempH = _sleepHours;
    int tempM = _sleepMinutes;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 280,
          child: Column(
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
                'Sleep Duration',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                          initialItem: tempH,
                        ),
                        onSelectedItemChanged: (v) => tempH = v,
                        children: List.generate(
                          24,
                          (i) => Center(child: Text('${i}h')),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                          initialItem: (tempM ~/ 5),
                        ),
                        onSelectedItemChanged: (v) => tempM = v * 5,
                        children: List.generate(
                          12,
                          (i) => Center(child: Text('${i * 5}m')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _sleepHours = tempH;
                            _sleepMinutes = tempM;
                            if (_bedTime != null) {
                              _recalcWakeFromBedAndDuration();
                            }
                          });
                        },
                        child: const Text('Set'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickRepeat() async {
    List<bool> temp = List<bool>.from(_repeat);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return StatefulBuilder(
          builder: (c, setM) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    'Repeat Days',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final selected = temp[i];
                      return ChoiceChip(
                        label: Text(names[i]),
                        selected: selected,
                        onSelected: (v) {
                          setM(() => temp[i] = v);
                        },
                        selectedColor: TColor.primaryColor2.withOpacity(0.8),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _repeat = temp;
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    if (_wakeTime == null) {
      // derive wake from duration
      _recalcWakeFromBedAndDuration();
    } else if (!_hasDuration && _bedTime != null) {
      _recalcDurationFromBedAndWake();
    }
    final duration = Duration(hours: _sleepHours, minutes: _sleepMinutes);
    final alarmTime = _wakeTime ?? _bedTime!.add(duration);
    Navigator.pop(context, {
      'bedTime': _bedTime!.toIso8601String(),
      'alarmTime': alarmTime.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'repeatDays': List<int>.generate(
        7,
        (i) => i,
      ).where((i) => _repeat[i]).toList(), // 0=Mon .. 6=Sun
    });
  }

  void _recalcWakeFromBedAndDuration() {
    if (_bedTime == null) return;
    _wakeTime = _bedTime!.add(
      Duration(hours: _sleepHours, minutes: _sleepMinutes),
    );
  }

  void _recalcDurationFromBedAndWake() {
    if (_bedTime == null || _wakeTime == null) return;
    var diff = _wakeTime!.difference(_bedTime!);
    if (diff.isNegative) diff += const Duration(days: 1);
    _sleepHours = diff.inHours;
    _sleepMinutes = diff.inMinutes % 60;
  }

  @override
  Widget build(BuildContext context) {
    // media not currently needed after UI changes

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
          "Add Alarm",
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
            const SizedBox(height: 8),
            IconTitleNextRow(
              icon: "assets/img/Bed_Add.png",
              title: "Bedtime",
              time: _bedTimeLabel,
              color: TColor.lightGray,
              onPressed: _pickBedTime,
            ),
            const SizedBox(height: 10),
            IconTitleNextRow(
              icon: "assets/img/HoursTime.png",
              title: "Hours of sleep",
              time: _durationLabel,
              color: TColor.lightGray,
              onPressed: _pickDuration,
            ),
            const SizedBox(height: 10),
            IconTitleNextRow(
              icon: "assets/img/alaarm.png",
              title: "Wake Up",
              time: _wakeTimeLabel,
              color: TColor.lightGray,
              onPressed: _pickWakeTime,
            ),
            const SizedBox(height: 10),
            IconTitleNextRow(
              icon: "assets/img/Repeat.png",
              title: "Repeat",
              time: _repeatLabel,
              color: TColor.lightGray,
              onPressed: _pickRepeat,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: TColor.lightGray,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 15),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: Image.asset(
                      "assets/img/Vibrate.png",
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Vibrate When Alarm Sound",
                      style: TextStyle(color: TColor.gray, fontSize: 12),
                    ),
                  ),

                  SizedBox(
                    height: 30,
                    child: Transform.scale(
                      scale: 0.7,
                      child: CustomAnimatedToggleSwitch<bool>(
                        current: positive,
                        values: [false, true],
                        dif: 0.0,
                        indicatorSize: const Size.square(30.0),
                        animationDuration: const Duration(milliseconds: 200),
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
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Opacity(
              opacity: _canSubmit ? 1.0 : 0.5,
              child: RoundButton(
                title: "Add",
                onPressed: () {
                  if (_canSubmit) _submit();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
