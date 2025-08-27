import 'package:animated_toggle_switch/animated_toggle_switch.dart';

import 'package:flutter/material.dart';

import '../common/color_extension.dart';
import '../common/common.dart';

class TodaySleepScheduleRow extends StatefulWidget {
  final Map sObj;
  final bool initialToggle;
  final void Function(bool)? onToggleChanged;
  const TodaySleepScheduleRow({
    super.key,
    required this.sObj,
    this.initialToggle = false,
    this.onToggleChanged,
  });

  @override
  State<TodaySleepScheduleRow> createState() => _TodaySleepScheduleRowState();
}

class _TodaySleepScheduleRowState extends State<TodaySleepScheduleRow> {
  late bool positive;

  @override
  void initState() {
    super.initState();
    positive = widget.initialToggle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: TColor.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              widget.sObj["image"].toString(),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.sObj["name"].toString(),
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.sObj["time"].toString() == '-' ||
                              widget.sObj["time"].toString().trim().isEmpty
                          ? " Not set"
                          : ", ${getStringDateToOtherFormate(widget.sObj["time"].toString())}",
                      style: TextStyle(color: TColor.black, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  widget.sObj["duration"].toString(),
                  style: TextStyle(
                    color: TColor.gray,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 30,
                child: Switch(
                  value: positive,
                  onChanged: (b) {
                    setState(() => positive = b);
                    if (widget.onToggleChanged != null) {
                      widget.onToggleChanged!(b);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
