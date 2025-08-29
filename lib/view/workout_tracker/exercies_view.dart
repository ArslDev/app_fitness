import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../common/color_extension.dart';

class ExerciesView extends StatefulWidget {
  final List steps; // list of maps with no,title,title,detail,image,seconds
  final String? imagePath; // optional global fallback image
  final String? workoutName; // to attribute progress
  const ExerciesView({
    super.key,
    required this.steps,
    this.imagePath,
    this.workoutName,
  });

  @override
  State<ExerciesView> createState() => _ExerciesViewState();
}

class _ExerciesViewState extends State<ExerciesView> {
  static const int defaultSecondsPerExercise = 30; // increased from 20 to 30
  static const int restSeconds = 10; // rest duration between exercises
  static const double _caloriesPerMinute = 8; // simple assumption
  double get _caloriesPerSecond => _caloriesPerMinute / 60.0;
  int _currentIndex = 0;
  int _remaining = defaultSecondsPerExercise;
  Timer? _timer;
  bool _finished = false;
  bool _paused = false;
  bool _isCountdown = true; // true while showing 3-second pre-start countdown
  int _countdown = 3;
  bool _isResting = false; // true during rest phase
  int _restRemaining = restSeconds;
  // Transition overlay (feature 9)
  bool _overlayVisible = false;
  bool _progressSaved = false; // ensure we save only once per session end/exit
  double _lastAnimatedProgress =
      0.0; // remember previous progress value for smooth animation

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  int _currentStepDuration() {
    if (_currentIndex < widget.steps.length) {
      final step = widget.steps[_currentIndex] as Map? ?? {};
      final raw = step['seconds'];
      if (raw is int && raw > 0) return raw;
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return defaultSecondsPerExercise;
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = _currentStepDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return; // do nothing while paused
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _advance();
        }
      });
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _isCountdown = true;
      _countdown = 3;
    });
    _playTransition();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return; // pause countdown too
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _isCountdown = false;
          _startTimer();
        }
      });
    });
  }

  void _advance() {
    if (_isResting) {
      // Rest just finished -> start countdown for next exercise
      _isResting = false;
      _startCountdown();
      return;
    }
    if (_currentIndex < widget.steps.length - 1) {
      // Determine if next step is an explicit rest step (title contains 'rest')
      final next = widget.steps[_currentIndex + 1] as Map? ?? {};
      final nextTitle = (next['title'] ?? '').toString().toLowerCase();
      final current = widget.steps[_currentIndex] as Map? ?? {};
      final currentTitle = (current['title'] ?? '').toString().toLowerCase();
      final isExplicitRestNext = nextTitle.contains('rest');
      final isExplicitRestCurrent = currentTitle.contains('rest');
      if (!isExplicitRestNext && !isExplicitRestCurrent) {
        // Insert automatic rest only if neither current nor next is an explicit rest step
        _isResting = true;
        _restRemaining = restSeconds;
        _startRest();
        return;
      } else {
        // Skip auto rest and move directly to next step
        _currentIndex++;
        _startCountdown();
        return;
      }
    } else {
      _finished = true;
      _timer?.cancel();
      _recordProgress(100.0); // auto record full completion
    }
  }

  void _goToPrevious() {
    if (_finished) return; // no back after finish screen
    if (_isResting) {
      // Currently resting after exercise at _currentIndex; previous means go to previous exercise (if exists)
      if (_currentIndex == 0) return; // nothing before
      _timer?.cancel();
      setState(() {
        _isResting = false;
        _currentIndex -= 1;
      });
      _startCountdown();
    } else if (_isCountdown) {
      if (_currentIndex == 0) return;
      _timer?.cancel();
      setState(() {
        _currentIndex -= 1;
      });
      _startCountdown();
    } else {
      // active exercise
      if (_currentIndex == 0) return;
      _timer?.cancel();
      setState(() {
        _currentIndex -= 1;
      });
      _startCountdown();
    }
  }

  void _nextManually() {
    setState(() {
      _advance();
    });
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
    });
  }

  void _startRest() {
    _timer?.cancel();
    setState(() {
      _isCountdown = false;
    });
    _playTransition();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return;
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          // Move to next exercise index
          _currentIndex++;
          _advance(); // this will trigger countdown for next exercise
        }
      });
    });
  }

  int _durationForIndex(int index) {
    if (index < 0 || index >= widget.steps.length)
      return defaultSecondsPerExercise;
    final step = widget.steps[index] as Map? ?? {};
    final raw = step['seconds'];
    if (raw is int && raw > 0) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    return defaultSecondsPerExercise;
  }

  double _caloriesForDuration(int seconds) => seconds * _caloriesPerSecond;

  double _totalCaloriesSoFar() {
    double sum = 0;
    for (int i = 0; i < widget.steps.length; i++) {
      int dur = _durationForIndex(i);
      if (i < _currentIndex) {
        sum += _caloriesForDuration(dur);
      } else if (i == _currentIndex) {
        if (_finished || _isResting) {
          sum += _caloriesForDuration(dur);
        } else if (!_isCountdown) {
          int elapsed = dur - _remaining;
          if (elapsed < 0) elapsed = 0;
          sum += _caloriesForDuration(dur) * (elapsed / dur);
        }
      }
    }
    return sum;
  }

  double _currentExerciseCaloriesBurned() {
    int dur = _durationForIndex(_currentIndex);
    if (_finished || _isResting) return _caloriesForDuration(dur);
    if (_isCountdown) return 0;
    int elapsed = dur - _remaining;
    if (elapsed < 0) elapsed = 0;
    return _caloriesForDuration(dur) * (elapsed / dur);
  }

  double _currentExerciseCaloriesTotal() =>
      _caloriesForDuration(_durationForIndex(_currentIndex));

  int _workoutRemainingSeconds() {
    if (_finished) return 0;
    int total = 0;
    // Current phase remaining
    if (_isCountdown) {
      total += _countdown;
      // full exercise still ahead
      total += _durationForIndex(_currentIndex);
      if (_currentIndex < widget.steps.length - 1)
        total += restSeconds; // rest after exercise (unless last)
    } else if (_isResting) {
      total += _restRemaining;
    } else {
      total += _remaining;
      if (_currentIndex < widget.steps.length - 1)
        total += restSeconds; // upcoming rest
    }
    // Future exercises (after current index if resting add +1 else +1 after current exercise)
    int startIndex;
    if (_isResting) {
      // next exercise index will be currentIndex + 1
      startIndex = _currentIndex + 1;
    } else {
      startIndex = _currentIndex + 1;
    }
    for (int i = startIndex; i < widget.steps.length; i++) {
      total += _durationForIndex(i);
      if (i < widget.steps.length - 1)
        total += restSeconds; // rest after each except last
    }
    return total;
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _playTransition() {
    // Show a dark overlay briefly then fade out
    setState(() {
      _overlayVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _overlayVisible = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_progressSaved && !_finished) {
      // User may have left mid-workout via system back; attempt save partial
      _recordProgress(_currentPercent());
    }
    super.dispose();
  }

  int _totalActiveSeconds() {
    int sum = 0;
    for (int i = 0; i < widget.steps.length; i++) {
      sum += _durationForIndex(i);
    }
    return sum;
  }

  int _autoRestCount() {
    int c = 0;
    for (int i = 0; i < widget.steps.length - 1; i++) {
      final cur =
          (widget.steps[i] as Map? ?? {})['title']?.toString().toLowerCase() ??
          '';
      final nxt =
          (widget.steps[i + 1] as Map? ?? {})['title']
              ?.toString()
              .toLowerCase() ??
          '';
      final explicitCur = cur.contains('rest');
      final explicitNext = nxt.contains('rest');
      if (!explicitCur && !explicitNext) c++;
    }
    return c;
  }

  int _totalRestSeconds() => _autoRestCount() * restSeconds;

  int _totalWorkoutSeconds() => _totalActiveSeconds() + _totalRestSeconds();

  void _restartWorkout() {
    _timer?.cancel();
    setState(() {
      _currentIndex = 0;
      _remaining = defaultSecondsPerExercise;
      _finished = false;
      _paused = false;
      _isCountdown = true;
      _countdown = 3;
      _isResting = false;
      _restRemaining = restSeconds;
      _progressSaved = false;
    });
    _startCountdown();
  }

  double _currentPercent() {
    if (_finished) return 100.0;
    final total = widget.steps.length;
    if (total == 0) return 0.0;
    double completed = _currentIndex.toDouble(); // fully completed exercises
    // add partial progress for current active exercise (exclude rest & countdown)
    if (!_isCountdown && !_isResting && !_finished) {
      final dur = _currentStepDuration();
      final elapsed = dur - _remaining;
      if (dur > 0 && elapsed > 0) {
        completed += (elapsed / dur).clamp(0.0, 1.0);
      }
    }
    return (completed / total * 100).clamp(0.0, 100.0);
  }

  int _completedExercisesCount() {
    if (_finished) return widget.steps.length;
    if (_isResting) return _currentIndex + 1; // just finished this one
    if (_isCountdown) return _currentIndex; // usually 0
    // active exercise not yet completed
    return _currentIndex;
  }

  double _discretePercent() {
    final total = widget.steps.length;
    if (total == 0) return 0;
    return (_completedExercisesCount() / total * 100).clamp(0, 100);
  }

  Future<void> _recordProgress(double percent) async {
    if (_progressSaved) return;
    _progressSaved = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'workout_daily_progress';
      Map<String, dynamic> data = {};
      final raw = prefs.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
      final today = DateTime.now();
      final dateKey =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // Store max percent for the day (if user repeats keep best achievement)
      final existing = data[dateKey];
      if (existing is num) {
        if (percent < existing.toDouble()) {
          percent = existing.toDouble();
        }
      }
      data[dateKey] = double.parse(percent.toStringAsFixed(2));
      // Optionally keep only last 14 days to limit size
      final keys = data.keys.toList();
      keys.sort();
      if (keys.length > 20) {
        final removeCount = keys.length - 20;
        for (int i = 0; i < removeCount; i++) {
          data.remove(keys[i]);
        }
      }
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentIndex] as Map? ?? {};
    final title = step['title']?.toString() ?? 'Exercise';
    final detail = step['detail']?.toString() ?? '';
    final no = step['no']?.toString() ?? '';
    final value = step['value']?.toString();
    final totalSeconds = _currentStepDuration();
    double progress;
    if (_finished) {
      progress = 1;
    } else if (_isResting) {
      progress = 1 - (_restRemaining / restSeconds);
    } else if (_isCountdown) {
      progress = 0.0;
    } else {
      progress = 1 - (_remaining / totalSeconds);
    }
    final stepImagePath = step['image']?.toString();
    // Upcoming exercise preview (next step)
    Map<String, dynamic>? nextStep;
    if (_currentIndex < widget.steps.length - 1) {
      nextStep = (widget.steps[_currentIndex + 1] as Map?)
          ?.cast<String, dynamic>();
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _finished
              ? 'Completed'
              : 'Exercise ${_currentIndex + 1}/${widget.steps.length}',
          style: TextStyle(
            color: TColor.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () async {
            if (_finished) {
              // Already finished; just close
              if (mounted) Navigator.pop(context, true);
              return;
            }
            // Show confirm dialog
            final completed = _completedExercisesCount();
            final total = widget.steps.length;
            final percent = _discretePercent();
            final exit = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Text('Exit Workout?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You completed $completed of $total exercises.'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation(
                          TColor.primaryColor1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${percent.toStringAsFixed(1)}% progress saved.'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Continue'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Exit'),
                    ),
                  ],
                );
              },
            );
            if (exit == true) {
              await _recordProgress(_discretePercent());
              if (mounted) Navigator.pop(context, true);
            }
          },
        ),
      ),
      backgroundColor: TColor.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _finished
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: TColor.primaryG),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              children: [
                                Image.asset("assets/img/complete_workout.png"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Workout Complete',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: TColor.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Great job! You finished all ${widget.steps.length} exercises.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.timer_outlined,
                          title: 'Duration',
                          value: _formatSeconds(_totalWorkoutSeconds()),
                          sub:
                              '${_formatSeconds(_totalActiveSeconds())} active',
                        ),
                        const SizedBox(width: 14),
                        _StatCard(
                          icon: Icons.local_fire_department_outlined,
                          title: 'Calories',
                          value: _totalCaloriesSoFar().toStringAsFixed(0),
                          sub: 'kcal',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.fitness_center_outlined,
                          title: 'Exercises',
                          value: widget.steps.length.toString(),
                          sub: 'completed',
                        ),
                        const SizedBox(width: 14),
                        _StatCard(
                          icon: Icons.bedtime_outlined,
                          title: 'Rest',
                          value: _autoRestCount().toString(),
                          sub: '${_totalRestSeconds()}s',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: TColor.primaryColor1,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _restartWorkout,
                            child: Text(
                              'Restart',
                              style: TextStyle(
                                color: TColor.primaryColor1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await _recordProgress(100.0);
                              if (mounted) Navigator.pop(context, true);
                            },
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: (_isCountdown || progress < _lastAnimatedProgress)
                          ? 0.0
                          : _lastAnimatedProgress,
                      end: progress.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.linear,
                    onEnd: () {
                      // Store the final animated value as baseline for next tick
                      _lastAnimatedProgress = progress.clamp(0.0, 1.0);
                    },
                    builder: (context, animatedValue, _) =>
                        LinearProgressIndicator(
                          value: animatedValue.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: TColor.lightGray,
                          valueColor: AlwaysStoppedAnimation(
                            _isResting
                                ? Colors.orangeAccent
                                : _isCountdown
                                ? TColor.gray
                                : TColor.primaryColor1,
                          ),
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (!_isResting)
                    Text(
                      no,
                      style: TextStyle(color: TColor.gray, fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  if (_isResting)
                    Text(
                      'Rest',
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      title,
                      style: TextStyle(
                        color: TColor.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (!_isResting &&
                      !_isCountdown &&
                      value != null &&
                      value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: TColor.gray,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _MediaBox(
                              path: stepImagePath,
                              fallback: widget.imagePath,
                            ),
                            if (_isCountdown)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: 1,
                                child: Text(
                                  _countdown.toString(),
                                  style: TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.9),
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(0, 2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Dark overlay transition (feature 9)
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 350),
                              opacity: _overlayVisible ? 0.55 : 0.0,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: TColor.primaryG),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _isResting
                                ? (nextStep != null
                                      ? 'Rest... Next: ${nextStep['title']} (${nextStep['seconds'] ?? defaultSecondsPerExercise}s)'
                                      : 'Rest...')
                                : _isCountdown
                                ? 'Get Ready...'
                                : detail,
                            style: TextStyle(color: TColor.white, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (nextStep != null && !_isResting && !_isCountdown)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Up Next: ',
                                  style: TextStyle(
                                    color: TColor.gray,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${nextStep['title']} (${nextStep['seconds'] ?? defaultSecondsPerExercise}s)',
                                  style: TextStyle(
                                    color: TColor.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isResting
                                  ? 'Rest: $_restRemaining s'
                                  : _isCountdown
                                  ? 'Starting in: $_countdown'
                                  : 'Time Left: $_remaining s',
                              style: TextStyle(
                                color: TColor.black,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Workout Left: ${_formatSeconds(_workoutRemainingSeconds())}',
                              style: TextStyle(
                                color: TColor.gray,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'Cal: ${_currentExerciseCaloriesBurned().toStringAsFixed(1)} / ${_currentExerciseCaloriesTotal().toStringAsFixed(1)}  |  Total: ${_totalCaloriesSoFar().toStringAsFixed(1)}',
                              style: TextStyle(
                                color: TColor.gray,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'Progress: ${_discretePercent().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: TColor.gray,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(70, 40),
                              ),
                              onPressed: (_currentIndex == 0 && !_isResting)
                                  ? null
                                  : _goToPrevious,
                              child: const Text('Prev'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(70, 40),
                              ),
                              onPressed: _togglePause,
                              child: Text(_paused ? 'Resume' : 'Pause'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(70, 40),
                              ),
                              onPressed: () async {
                                if (_isResting) {
                                  setState(() {
                                    _restRemaining = 0;
                                  });
                                  _advance();
                                } else {
                                  final isLast =
                                      _currentIndex == widget.steps.length - 1;
                                  if (isLast) {
                                    await _recordProgress(100.0);
                                  } else {
                                    await _recordProgress(_discretePercent());
                                  }
                                  _nextManually();
                                }
                              },
                              child: Text(
                                _isResting
                                    ? 'Skip Rest'
                                    : _currentIndex == widget.steps.length - 1
                                    ? 'Finish'
                                    : 'Skip',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _MediaBox extends StatelessWidget {
  final String? path;
  final String? fallback;
  const _MediaBox({this.path, this.fallback});

  bool get _isLottie => path != null && path!.toLowerCase().endsWith('.json');

  @override
  Widget build(BuildContext context) {
    final displayPath = path ?? fallback;
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black12,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Builder(
          builder: (_) {
            if (displayPath == null) {
              return const Center(child: Icon(Icons.image_not_supported));
            }
            if (_isLottie) {
              return Lottie.asset(
                displayPath,
                fit: BoxFit.contain,
                repeat: true,
              );
            }
            return Image.asset(
              displayPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image)),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? sub;
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColor.primaryG;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.first.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colors.first.withOpacity(0.15),
                    colors.last.withOpacity(0.15),
                  ],
                ),
              ),
              child: Icon(icon, color: colors.first, size: 22),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.65),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
