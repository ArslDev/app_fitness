import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:readmore/readmore.dart';

import '../../common/color_extension.dart';
import '../../common_widget/step_detail_row.dart';

class ExercisesStepDetails extends StatefulWidget {
  final Map eObj;

  const ExercisesStepDetails({super.key, required this.eObj});

  @override
  State<ExercisesStepDetails> createState() => _ExercisesStepDetailsState();
}

class _ExercisesStepDetailsState extends State<ExercisesStepDetails>
    with SingleTickerProviderStateMixin {
  List stepArr = [
    {
      "no": "01",
      "title": "Spread Your Arms",
      "detail":
          "To make the gestures feel more relaxed, stretch your arms as you start this movement. No bending of hands.",
      "image": "assets/img/m_1.png",
      "seconds": 20,
    },
    {
      "no": "02",
      "title": "Rest at The Toe",
      "detail":
          "The basis of this movement is jumping. Now, what needs to be considered is that you have to use the tips of your feet",
      "image": "assets/img/m_2.png",
      "seconds": 20,
    },
    {
      "no": "03",
      "title": "Adjust Foot Movement",
      "detail":
          "Jumping Jack is not just an ordinary jump. But, you also have to pay close attention to leg movements.",
      "image": "assets/img/m_3.png",
      "seconds": 20,
    },
    {
      "no": "04",
      "title": "Clapping Both Hands",
      "detail":
          "This cannot be taken lightly. You see, without realizing it, the clapping of your hands helps you to keep your rhythm while doing the Jumping Jack",
      "image": "assets/img/m_4.png",
      "seconds": 20,
    },
  ];
  Map? _selectedStep; // currently selected step
  AnimationController? _lottieController;
  bool _animPlaying = true;

  @override
  void initState() {
    super.initState();
    // If a preselected exercise passed in, attempt to set it
    final pre = widget.eObj['preselect'];
    if (pre is Map) {
      _selectedStep = pre;
    }
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    super.dispose();
  }

  bool _isLottie(String? p) => p != null && p.toLowerCase().endsWith('.json');

  Widget _buildMainMedia(double width) {
    final path = _selectedStep?['image'] ?? 'assets/img/video_temp.png';
    final isLottie = _isLottie(path);
    return Stack(
      children: [
        Container(
          width: width,
          height: width * 0.55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: TColor.primaryG,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              color: Colors.black12,
              child: isLottie
                  ? Lottie.asset(
                      path,
                      controller: _lottieController,
                      onLoaded: (c) {
                        _lottieController
                          ?..duration = c.duration
                          ..repeat();
                      },
                      fit: BoxFit.contain,
                    )
                  : Image.asset(path, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 16,
          right: 60,
          child: Text(
            (_selectedStep?['title'] ??
                    widget.eObj['preselect']?['title'] ??
                    widget.eObj['title'] ??
                    '')
                .toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_selectedStep?['seconds'] != null)
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '${_selectedStep!['seconds']}s',
                ),
              const SizedBox(height: 6),
              _InfoChip(
                icon: Icons.fitness_center,
                label: '${(_selectedStep?['no'] ?? '01')}',
              ),
            ],
          ),
        ),
        if (isLottie)
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _animPlaying = !_animPlaying;
                  if (_animPlaying) {
                    _lottieController?.repeat();
                  } else {
                    _lottieController?.stop();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
                child: Icon(
                  _animPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
      ],
    );
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
      ),
      backgroundColor: TColor.white,
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainMedia(media.width),
              const SizedBox(height: 15),
              Text(
                (_selectedStep?['title'] ??
                        (widget.eObj['preselect']?['title']) ??
                        widget.eObj["title"])
                    .toString(),
                style: TextStyle(
                  color: TColor.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Easy | 390 Calories Burn",
                style: TextStyle(color: TColor.gray, fontSize: 12),
              ),
              const SizedBox(height: 15),
              Text(
                "Descriptions",
                style: TextStyle(
                  color: TColor.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: TColor.lightGray.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                child: ReadMoreText(
                  'A jumping jack, also known as a star jump and called a side-straddle hop in the US military, is a physical jumping exercise performed by jumping to a position with the legs spread wide A jumping jack, also known as a star jump and called a side-straddle hop in the US military, is a physical jumping exercise performed by jumping to a position with the legs spread wide',
                  trimLines: 4,
                  colorClickableText: TColor.black,
                  trimMode: TrimMode.Line,
                  trimCollapsedText: ' Read More',
                  trimExpandedText: ' Read Less',
                  style: TextStyle(
                    color: TColor.gray,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  moreStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "How To Do It",
                    style: TextStyle(
                      color: TColor.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "${stepArr.length} Sets",
                      style: TextStyle(color: TColor.gray, fontSize: 12),
                    ),
                  ),
                ],
              ),
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: stepArr.length,
                itemBuilder: ((context, index) {
                  var sObj = stepArr[index] as Map? ?? {};

                  final bool selected = identical(_selectedStep, sObj);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStep = sObj;
                        if (_isLottie(_selectedStep?['image'])) {
                          _lottieController?.reset();
                          if (_animPlaying) {
                            _lottieController?.repeat();
                          }
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? TColor.primaryColor1
                              : Colors.transparent,
                          width: 1.4,
                        ),
                        color: selected
                            ? TColor.primaryColor1.withOpacity(0.08)
                            : Colors.transparent,
                      ),
                      child: StepDetailRow(
                        sObj: sObj,
                        isLast: stepArr.last == sObj,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
