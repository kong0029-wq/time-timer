import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronosApp());
}

// ----------------------------------------------------------------
// 0. 프리셋 데이터 모델 클래스
// ----------------------------------------------------------------
class PresetItem {
  final String id;
  final String title;
  final String? subtitle;
  final int totalSeconds;
  final String? tag;
  final IconData? icon;
  final String styleType;

  PresetItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.totalSeconds,
    this.tag,
    this.icon,
    required this.styleType,
  });
}

List<PresetItem> globalPresets = [];

// ----------------------------------------------------------------
// 1. 앱 테마 및 기본 설정 (StatefulWidget으로 변경하여 테마 상태 관리)
// ----------------------------------------------------------------
class ChronosApp extends StatefulWidget {
  const ChronosApp({super.key});

  @override
  State<ChronosApp> createState() => _ChronosAppState();
}

class _ChronosAppState extends State<ChronosApp> {
  // ★ 현재 테마 모드 상태 저장 (기본값: 시스템 설정 따름)
  ThemeMode _themeMode = ThemeMode.system;

  void _changeThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHRONOS',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode, // ★ 테마 모드 적용
      // 라이트 모드 테마
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9FB),
        primaryColor: const Color(0xFFB50008),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFFB50008),
          primary: const Color(0xFFB50008),
          surface: Colors.white,
          onSurface: const Color(0xFF1A1C1D),
          secondary: const Color(0xFFAD3127),
        ),
        textTheme: GoogleFonts.lexendTextTheme(ThemeData.light().textTheme),
      ),
      // 다크 모드 테마
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFB50008),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFB50008),
          primary: const Color(0xFFB50008),
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
          secondary: const Color(0xFFAD3127),
        ),
        textTheme: GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme),
      ),
      home: MainNavigationScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _changeThemeMode,
      ),
    );
  }
}

// ----------------------------------------------------------------
// 2. 메인 네비게이션
// ----------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const MainNavigationScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  int remainingSeconds = 45 * 60;
  int initialSeconds = 45 * 60;

  bool isRunning = false;

  bool enableSound = true;
  bool enableVibration = true;
  String selectedSoundType = 'notification';
  String? customSoundPath;
  Uint8List? customSoundBytes;
  int alarmDurationSeconds = 5; // 알림음 울림 시간 (초)

  String currentGoal = "독서";

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // 현재 다크 모드인지 확인
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    List<Widget> pages = [
      TimerMainPage(
        remainingSeconds: remainingSeconds,
        isRunning: isRunning,
        currentGoal: currentGoal,
        soundEnabled: enableSound,
        vibrationEnabled: enableVibration,
        selectedSoundType: selectedSoundType,
        customSoundPath: customSoundPath,
        customSoundBytes: customSoundBytes,
        alarmDurationSeconds: alarmDurationSeconds,
        onToggle: (val) => setState(() => isRunning = val),
        onSecondsChanged: (val) => setState(() {
          remainingSeconds = val;
          if (!isRunning) initialSeconds = val;
        }),
        onReset: () => setState(() {
          isRunning = false;
          remainingSeconds = initialSeconds;
        }),
        onClear: () => setState(() {
          isRunning = false;
          remainingSeconds = 0;
          initialSeconds = 0;
        }),
        onNavigateToPresets: () => setState(() => _selectedIndex = 1),
        onGoalChanged: (newGoal) => setState(() => currentGoal = newGoal),
      ),
      PresetsPage(
        onSelect: (secs) {
          setState(() {
            remainingSeconds = secs;
            initialSeconds = secs;
            _selectedIndex = 0;
          });
        },
      ),
      SettingsPage(
        sound: enableSound,
        vibration: enableVibration,
        selectedSoundType: selectedSoundType,
        alarmDurationSeconds: alarmDurationSeconds,
        themeMode: widget.themeMode, // 테마 설정 전달
        onSoundChanged: (val) => setState(() => enableSound = val),
        onVibrationChanged: (val) => setState(() => enableVibration = val),
        onSoundTypeChanged: (val) => setState(() => selectedSoundType = val),
        onAlarmDurationChanged: (val) => setState(() => alarmDurationSeconds = val),
        onCustomSoundPicked: (path, bytes) => setState(() {
          customSoundPath = path;
          customSoundBytes = bytes;
          selectedSoundType = 'custom';
        }),
        onThemeModeChanged: widget.onThemeModeChanged, // 테마 변경 함수 전달
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF121212).withAlpha(230)
            : Colors.white.withAlpha(230),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'CHRONOS',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF1A1C1D),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          height: 85,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E).withAlpha(240)
                : Colors.white.withAlpha(240),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(26)
                    : Colors.black.withAlpha(13),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.timer, "타이머", isDark),
              _navItem(1, Icons.list_alt, "프리셋", isDark),
              _navItem(2, Icons.settings, "설정", isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    bool isActive = _selectedIndex == index;
    Color inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFB50008) : inactiveColor,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFFB50008) : inactiveColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// 3. 타이머 메인 페이지
// ----------------------------------------------------------------
class TimerMainPage extends StatefulWidget {
  final int remainingSeconds;
  final bool isRunning;
  final String currentGoal;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String selectedSoundType;
  final String? customSoundPath;
  final Uint8List? customSoundBytes;
  final int alarmDurationSeconds;
  final Function(bool) onToggle;
  final Function(int) onSecondsChanged;
  final VoidCallback onReset;
  final VoidCallback onClear;
  final VoidCallback onNavigateToPresets;
  final Function(String) onGoalChanged;

  const TimerMainPage({
    super.key,
    required this.remainingSeconds,
    required this.isRunning,
    required this.currentGoal,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.selectedSoundType,
    this.customSoundPath,
    this.customSoundBytes,
    required this.alarmDurationSeconds,
    required this.onToggle,
    required this.onSecondsChanged,
    required this.onReset,
    required this.onClear,
    required this.onNavigateToPresets,
    required this.onGoalChanged,
  });

  @override
  State<TimerMainPage> createState() => _TimerMainPageState();
}

class _TimerMainPageState extends State<TimerMainPage> {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  double _lastAngle = 0;
  double _accumulatedSeconds = 0;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() async {
    if (widget.remainingSeconds <= 0) return;

    try {
      WakelockPlus.enable();
    } catch (e) {}

    widget.onToggle(true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.remainingSeconds > 0) {
        widget.onSecondsChanged(widget.remainingSeconds - 1);
      } else {
        _stopTimer();
        _playAlarm();
      }
    });
  }

  void _stopTimer() async {
    _timer?.cancel();
    widget.onToggle(false);
    try {
      WakelockPlus.disable();
    } catch (e) {}
  }

  void _stopAlarmManually() {
    _audioPlayer.stop();
    if (!kIsWeb) {
      FlutterRingtonePlayer().stop();
    }
  }

  void _playAlarm() {
    _stopAlarmManually(); // 기존 알람 중지
    if (widget.soundEnabled) {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      if (widget.selectedSoundType == 'custom') {
        if (kIsWeb && widget.customSoundBytes != null) {
          _audioPlayer.play(BytesSource(widget.customSoundBytes!));
        } else if (widget.customSoundPath != null) {
          _audioPlayer.play(DeviceFileSource(widget.customSoundPath!));
        }
      } else if (widget.selectedSoundType == 'beep') {
        _audioPlayer.play(AssetSource('beep.wav'));
      } else if (widget.selectedSoundType == 'chime') {
        _audioPlayer.play(AssetSource('chime.wav'));
      } else if (widget.selectedSoundType == 'win_alarm') {
        _audioPlayer.play(AssetSource('Alarm01.wav'));
      } else if (widget.selectedSoundType == 'win_ring') {
        _audioPlayer.play(AssetSource('Ring01.wav'));
      } else if (widget.selectedSoundType == 'win_tada') {
        _audioPlayer.play(AssetSource('tada.wav'));
      } else if (widget.selectedSoundType == 'win_chimes') {
        _audioPlayer.play(AssetSource('chimes.wav'));
      } else if (widget.selectedSoundType == 'win_notify') {
        _audioPlayer.play(AssetSource('notify.wav'));
      } else if (kIsWeb) {
        // 웹에서는 기본적으로 audioplayers를 사용하여 에셋 소리 재생
        _audioPlayer.play(AssetSource('alarm.mp3'));
      } else {
        // 모바일/데스크톱에서는 기존 링톤 플레이어 사용
        if (widget.selectedSoundType == 'alarm') {
          FlutterRingtonePlayer().playAlarm();
        } else if (widget.selectedSoundType == 'ringtone') {
          FlutterRingtonePlayer().playRingtone();
        } else {
          FlutterRingtonePlayer().playNotification();
        }
      }
      
      if (widget.alarmDurationSeconds > 0) {
        Timer(Duration(seconds: widget.alarmDurationSeconds), () {
          _stopAlarmManually();
        });
      }
    }
    if (widget.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _resetTimer() {
    _stopAlarmManually();
    if (widget.isRunning) return;
    widget.onReset();
  }

  void _clearTimer() {
    _stopAlarmManually();
    if (widget.isRunning) return;
    widget.onClear();
  }

  double _calculateAngle(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    double angle = atan2(dy, dx);
    double normalized = (angle + pi / 2) % (2 * pi);
    if (normalized < 0) {
      normalized += 2 * pi;
    }
    return normalized;
  }

  void _onPanStart(DragStartDetails details, double size) {
    _stopAlarmManually();
    if (widget.isRunning) return;
    _lastAngle = _calculateAngle(details.localPosition, Size(size, size));
    _accumulatedSeconds = widget.remainingSeconds.toDouble();
  }

  void _onPanUpdate(DragUpdateDetails details, double size) {
    if (widget.isRunning) return;
    double currentAngle = _calculateAngle(
      details.localPosition,
      Size(size, size),
    );
    double deltaAngle = currentAngle - _lastAngle;

    if (deltaAngle > pi) {
      deltaAngle -= 2 * pi;
    } else if (deltaAngle < -pi) {
      deltaAngle += 2 * pi;
    }

    _accumulatedSeconds += (deltaAngle / (2 * pi)) * 3600;

    if (_accumulatedSeconds < 0) {
      _accumulatedSeconds = 0;
    } else if (_accumulatedSeconds > 86400) {
      _accumulatedSeconds = 86400;
    }

    widget.onSecondsChanged(_accumulatedSeconds.round());
    _lastAngle = currentAngle;
  }

  void _showGoalInputDialog(bool isDark) {
    TextEditingController goalController = TextEditingController(
      text: widget.currentGoal,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '현재 목표 설정',
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFB50008),
            ),
          ),
          content: TextField(
            controller: goalController,
            autofocus: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: '무엇에 집중하시나요?',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFB50008),
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                widget.onGoalChanged(value.trim());
              }
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (goalController.text.trim().isNotEmpty) {
                  widget.onGoalChanged(goalController.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFFB50008),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTimeInputDialog(bool isDark) {
    TextEditingController minController = TextEditingController(
      text: (widget.remainingSeconds ~/ 60).toString(),
    );
    TextEditingController secController = TextEditingController(
      text: (widget.remainingSeconds % 60).toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '시간 설정',
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFB50008),
            ),
          ),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: '분',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: secController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: '초',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                int m = int.tryParse(minController.text) ?? 0;
                int s = int.tryParse(secController.text) ?? 0;

                int totalSecs = max(0, m * 60 + s);
                if (totalSecs > 86400) {
                  totalSecs = 86400;
                }

                widget.onSecondsChanged(totalSecs);
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFFB50008),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSavePresetDialog(bool isDark) {
    int currentSecs = widget.remainingSeconds;

    if (currentSecs == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("시간을 설정한 후 프리셋으로 저장할 수 있습니다.")),
      );
      return;
    }

    int displayMins = currentSecs ~/ 60;
    int displaySecs = currentSecs % 60;
    String timeLabel = displaySecs == 0
        ? '$displayMins분'
        : '$displayMins분 $displaySecs초';

    TextEditingController titleController = TextEditingController(
      text: widget.currentGoal.isNotEmpty
          ? widget.currentGoal
          : '나만의 집중 $timeLabel',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.bookmark_add, color: Color(0xFFB50008)),
              const SizedBox(width: 8),
              Text(
                '프리셋 저장',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB50008),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "현재 설정된 시간 ($timeLabel)을 라이브러리에 저장합니다.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: '프리셋 이름',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFEEEEF0),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  globalPresets.add(
                    PresetItem(
                      id: DateTime.now().toString(),
                      title: titleController.text.isNotEmpty
                          ? titleController.text
                          : '이름 없음',
                      totalSeconds: currentSecs,
                      styleType: 'light',
                    ),
                  );
                });
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("프리셋이 저장되었습니다."),
                    action: SnackBarAction(
                      label: '확인하기',
                      textColor: Colors.white,
                      onPressed: widget.onNavigateToPresets,
                    ),
                  ),
                );
              },
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Color(0xFFB50008),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    String minStr = (widget.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    String secStr = (widget.remainingSeconds % 60).toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        double timerSize = min(constraints.maxWidth * 0.8, 400);
        double bgFontSize = min(constraints.maxWidth * 0.5, 240);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "현재 목표",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black38,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.isRunning
                      ? null
                      : () => _showGoalInputDialog(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFEEEEF0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.currentGoal,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          color: widget.isRunning
                              ? Colors.transparent
                              : (isDark ? Colors.white24 : Colors.black26),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 배경의 거대한 숫자 (분)
                    Text(
                      "${widget.remainingSeconds ~/ 60}",
                      style: TextStyle(
                        fontSize: bgFontSize,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(8),
                        height: 1,
                      ),
                    ),
                    GestureDetector(
                      onPanStart: (details) => _onPanStart(details, timerSize),
                      onPanUpdate: (details) =>
                          _onPanUpdate(details, timerSize),
                      child: SizedBox(
                        width: timerSize,
                        height: timerSize,
                        child: CustomPaint(
                          painter: ChronosTimerPainter(
                            seconds: widget.remainingSeconds,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: GestureDetector(
                        onTap: widget.isRunning
                            ? null
                            : () => _showTimeInputDialog(isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E).withAlpha(240)
                                : Colors.white.withAlpha(240),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.white,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            "$minStr:$secStr",
                            style: GoogleFonts.lexend(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  "가장자리를 드래그하거나 텍스트를 탭하여 수정하세요",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 60),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 75,
                        child: ElevatedButton(
                          onPressed: widget.isRunning
                              ? _stopTimer
                              : _startTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB50008),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 15,
                            shadowColor: const Color(0xFFB50008).withAlpha(76),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.isRunning ? "중지" : "시작",
                                style: GoogleFonts.lexend(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                widget.isRunning
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 75,
                      width: 75,
                      child: ElevatedButton(
                        onPressed: widget.isRunning ? null : _resetTimer,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isDark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFEEEEF0),
                          foregroundColor: widget.isRunning
                              ? Colors.grey[600]
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1C1D)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.refresh, size: 30),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 75,
                      width: 75,
                      child: ElevatedButton(
                        onPressed: widget.isRunning ? null : _clearTimer,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isDark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFEEEEF0),
                          foregroundColor: widget.isRunning
                              ? Colors.grey[600]
                              : const Color(0xFFB50008),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.stop, size: 30),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                if (!widget.isRunning)
                  InkWell(
                    onTap: () => _showSavePresetDialog(isDark),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFB50008),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bookmark_add,
                            color: Color(0xFFB50008),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "프리셋 저장",
                            style: GoogleFonts.lexend(
                              color: const Color(0xFFB50008),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------
// 타이머 그리기 (다크 모드 색상 적용)
// ----------------------------------------------------------------
class ChronosTimerPainter extends CustomPainter {
  final int seconds;
  final bool isDark; // ★ 추가됨

  ChronosTimerPainter({required this.seconds, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius - 7, trackPaint);

    if (seconds > 0) {
      int round = (seconds - 1) ~/ 3600;
      int displaySeconds = seconds % 3600;
      if (displaySeconds == 0) displaySeconds = 3600;

      List<List<Color>> palette = [
        [const Color(0xFFB50008), const Color(0xFFE01616)],
        [const Color(0xFF004CB5), const Color(0xFF166DE0)],
        [const Color(0xFF007A33), const Color(0xFF16A34A)],
        [const Color(0xFFB56E00), const Color(0xFFE09016)],
        [const Color(0xFF6200B5), const Color(0xFF8B16E0)],
      ];

      int currentIdx = round % palette.length;
      List<Color> currentColors = palette[currentIdx];

      final rect = Rect.fromCircle(
        center: center,
        radius: (radius - 14) * 0.88,
      );

      if (round > 0) {
        int prevIdx = (round - 1) % palette.length;
        List<Color> prevColors = palette[prevIdx];
        final bgPaint = Paint()
          ..shader = LinearGradient(
            colors: prevColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, (radius - 14) * 0.88, bgPaint);
      }

      final diskPaint = Paint()
        ..shader = LinearGradient(
          colors: currentColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      double sweepAngle = (displaySeconds / 3600) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, true, diskPaint);
    }

    // 중앙 데코레이션
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..color = isDark ? const Color(0xFF1E1E1E) : Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      4,
      Paint()..color = const Color(0xFFB50008).withAlpha(51),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------------------------------------------------------
// 4. 프리셋 페이지
// ----------------------------------------------------------------
class PresetsPage extends StatefulWidget {
  final Function(int) onSelect;
  const PresetsPage({super.key, required this.onSelect});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
  void _confirmDelete(PresetItem item, bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          title: Text(
            '프리셋 삭제',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            "'${item.title}' 프리셋을 삭제하시겠습니까?",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFB50008),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                setState(
                  () => globalPresets.removeWhere((p) => p.id == item.id),
                );
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 450;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "라이브러리",
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB50008),
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "프리셋",
                style: GoogleFonts.lexend(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              if (globalPresets.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  alignment: Alignment.center,
                  child: Text(
                    "저장된 프리셋이 없습니다.\n타이머 화면에서 '프리셋 저장' 버튼을 눌러보세요.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      color: isDark ? Colors.white38 : Colors.black38,
                      height: 1.5,
                    ),
                  ),
                )
              else
                ..._buildDynamicGrid(isSmallScreen, isDark),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDynamicGrid(bool isSmallScreen, bool isDark) {
    List<Widget> gridWidgets = [];

    for (int i = 0; i < globalPresets.length; i++) {
      final current = globalPresets[i];
      final bool isHalfSize =
          (current.styleType == 'light' || current.styleType == 'outline') &&
          !isSmallScreen;

      if (isHalfSize) {
        final hasNextHalf =
            (i + 1 < globalPresets.length) &&
            (globalPresets[i + 1].styleType == 'light' ||
                globalPresets[i + 1].styleType == 'outline');
        if (hasNextHalf) {
          gridWidgets.add(
            Row(
              children: [
                Expanded(child: _renderCard(current, isDark)),
                const SizedBox(width: 16),
                Expanded(child: _renderCard(globalPresets[i + 1], isDark)),
              ],
            ),
          );
          i++;
        } else {
          gridWidgets.add(
            Row(
              children: [
                Expanded(child: _renderCard(current, isDark)),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          );
        }
      } else {
        gridWidgets.add(_renderCard(current, isDark));
      }
      gridWidgets.add(const SizedBox(height: 16));
    }
    return gridWidgets;
  }

  Widget _renderCard(PresetItem item, bool isDark) {
    Widget card;
    Color deleteIconColor = isDark
        ? Colors.white.withAlpha(150)
        : const Color(0xFFB50008).withAlpha(100);

    if (item.styleType == 'long') {
      card = _buildLongCard(
        title: item.title,
        totalSeconds: item.totalSeconds,
        icon: item.icon ?? Icons.timer,
        isDark: isDark,
      );
    } else {
      bool isLarge = item.styleType == 'main';
      bool isDarkStyle = item.styleType == 'dark';
      bool hasBorder = item.styleType == 'outline';

      if (isDarkStyle) {
        deleteIconColor = Colors.white.withAlpha(150);
      }

      Color color = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      if (item.styleType == 'light') {
        color = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEF0);
      } else if (item.styleType == 'dark') {
        color = const Color(0xFFB50008);
      }

      card = _buildBentoCard(
        color: color,
        title: item.title,
        subtitle: item.subtitle,
        totalSeconds: item.totalSeconds,
        tag: item.tag,
        isLarge: isLarge,
        hasBorder: hasBorder,
        isDarkStyle: isDarkStyle,
        isDarkTheme: isDark,
      );
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        GestureDetector(
          onTap: () => widget.onSelect(item.totalSeconds),
          child: card,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: deleteIconColor,
            onPressed: () => _confirmDelete(item, isDark),
            tooltip: '프리셋 삭제',
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required Color color,
    required String title,
    String? subtitle,
    required int totalSeconds,
    String? tag,
    required bool isLarge,
    bool hasBorder = false,
    bool isDarkStyle = false,
    required bool isDarkTheme,
  }) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    String timeStr = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      height: isLarge ? 280 : 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: hasBorder
            ? Border.all(
                color: isDarkTheme
                    ? Colors.white24
                    : Colors.black.withAlpha(13),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB50008).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB50008),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: isLarge ? 28 : 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkStyle
                      ? Colors.white
                      : (isDarkTheme ? Colors.white : const Color(0xFF1A1C1D)),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkTheme ? Colors.white54 : Colors.black38,
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeStr,
                style: GoogleFonts.lexend(
                  fontSize: isLarge ? 32 : 22,
                  fontWeight: FontWeight.w900,
                  color: isDarkStyle
                      ? Colors.white
                      : (isLarge
                            ? const Color(0xFFB50008)
                            : (isDarkTheme ? Colors.white : Colors.black87)),
                ),
              ),
              Icon(
                Icons.play_circle_fill,
                color: isDarkStyle
                    ? Colors.white
                    : (isLarge
                          ? const Color(0xFFB50008)
                          : (isDarkTheme ? Colors.white70 : Colors.black87)),
                size: isLarge ? 50 : 35,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLongCard({
    required String title,
    required int totalSeconds,
    required IconData icon,
    required bool isDark,
  }) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    String timeStr = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEF0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFFB50008)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Text(
            timeStr,
            style: GoogleFonts.lexend(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.play_circle_fill,
            size: 40,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// 6. 설정 페이지 (테마 설정 추가)
// ----------------------------------------------------------------
class SettingsPage extends StatelessWidget {
  final bool sound;
  final bool vibration;
  final String selectedSoundType;
  final int alarmDurationSeconds;
  final ThemeMode themeMode; // ★ 추가됨
  final Function(bool) onSoundChanged;
  final Function(bool) onVibrationChanged;
  final Function(String) onSoundTypeChanged;
  final Function(int) onAlarmDurationChanged;
  final Function(String?, Uint8List?) onCustomSoundPicked;
  final Function(ThemeMode) onThemeModeChanged; // ★ 추가됨

  const SettingsPage({
    super.key,
    required this.sound,
    required this.vibration,
    required this.selectedSoundType,
    required this.alarmDurationSeconds,
    required this.themeMode,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onSoundTypeChanged,
    required this.onAlarmDurationChanged,
    required this.onCustomSoundPicked,
    required this.onThemeModeChanged,
  });

  void _showSoundPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Text(
                "알림음 선택",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  "기본 알림음",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'notification'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('notification');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "알람 소리",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'alarm'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('alarm');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "전화벨 소리",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'ringtone'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('ringtone');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "경쾌한 삑 소리",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'beep'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('beep');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "부드러운 종소리",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'chime'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('chime');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "윈도우 알람",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'win_alarm'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('win_alarm');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "윈도우 전화벨",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'win_ring'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('win_ring');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "윈도우 짜잔(Tada)",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'win_tada'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('win_tada');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "윈도우 차임벨",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'win_chimes'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('win_chimes');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "윈도우 일반 알림",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'win_notify'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onSoundTypeChanged('win_notify');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "사용자 선택...",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: selectedSoundType == 'custom'
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                      withData: kIsWeb, // 웹에서는 바이트 데이터 필요
                    );
                    
                    if (result != null) {
                      final path = kIsWeb ? null : result.files.single.path;
                      final bytes = result.files.single.bytes;
                      onCustomSoundPicked(path, bytes);
                    }

                  } catch (e) {
                    debugPrint('Error picking file: $e');
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        );
      },
    );
  }

  void _showDurationPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final options = {
          3: '3초',
          5: '5초',
          10: '10초',
          30: '30초',
          60: '1분',
          0: '계속 울림',
        };

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Text(
                "알림음 울림 시간",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...options.entries.map((entry) {
                return ListTile(
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: alarmDurationSeconds == entry.key
                      ? const Icon(Icons.check, color: Color(0xFFB50008))
                      : null,
                  onTap: () {
                    onAlarmDurationChanged(entry.key);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ★ 테마 선택 팝업 띄우기
  void _showThemePicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Text(
                "테마 설정",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  "시스템 기본값",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: themeMode == ThemeMode.system
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onThemeModeChanged(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "라이트 모드",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: themeMode == ThemeMode.light
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onThemeModeChanged(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(
                  "다크 모드",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: themeMode == ThemeMode.dark
                    ? const Icon(Icons.check, color: Color(0xFFB50008))
                    : null,
                onTap: () {
                  onThemeModeChanged(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    String soundDisplayName = '기본 알림음';
    if (selectedSoundType == 'alarm') soundDisplayName = '알람 소리';
    if (selectedSoundType == 'ringtone') soundDisplayName = '전화벨 소리';

    String themeDisplayName = '시스템 기본값';
    if (themeMode == ThemeMode.light) themeDisplayName = '라이트 모드';
    if (themeMode == ThemeMode.dark) themeDisplayName = '다크 모드';

    String durationDisplayName = alarmDurationSeconds == 0
        ? '계속 울림'
        : (alarmDurationSeconds >= 60 ? '${alarmDurationSeconds ~/ 60}분' : '${alarmDurationSeconds}초');

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 450;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "시스템",
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB50008),
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "설정",
                style: GoogleFonts.lexend(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              if (isSmallScreen)
                Column(
                  children: [
                    _buildSettingToggle(
                      "소리 알림",
                      Icons.volume_up,
                      sound,
                      onSoundChanged,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSettingToggle(
                      "햅틱 피드백",
                      Icons.vibration,
                      vibration,
                      onVibrationChanged,
                      isLightBox: true,
                      isDark: isDark,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildSettingToggle(
                        "소리 알림",
                        Icons.volume_up,
                        sound,
                        onSoundChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSettingToggle(
                        "햅틱 피드백",
                        Icons.vibration,
                        vibration,
                        onVibrationChanged,
                        isLightBox: true,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // 알림음 변경 메뉴
              InkWell(
                onTap: sound ? () => _showSoundPicker(context, isDark) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFEEEEF0).withAlpha(127),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "알림음 변경",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sound
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white38 : Colors.grey),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            soundDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: sound
                                  ? const Color(0xFFB50008)
                                  : (isDark ? Colors.white38 : Colors.grey),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: sound
                                ? (isDark ? Colors.white24 : Colors.black26)
                                : (isDark ? Colors.white10 : Colors.grey[300]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 알림음 울림 시간 설정 메뉴
              InkWell(
                onTap: sound ? () => _showDurationPicker(context, isDark) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFEEEEF0).withAlpha(127),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "알림음 울림 시간",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sound
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white38 : Colors.grey),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            durationDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: sound
                                  ? const Color(0xFFB50008)
                                  : (isDark ? Colors.white38 : Colors.grey),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: sound
                                ? (isDark ? Colors.white24 : Colors.black26)
                                : (isDark ? Colors.white10 : Colors.grey[300]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ★ 테마 설정 메뉴
              InkWell(
                onTap: () => _showThemePicker(context, isDark),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFEEEEF0).withAlpha(127),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "테마 설정",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            themeDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFFB50008),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              _buildInfoCard("CHRONOS 정보", "버전 2.4.0 • 집중에 최적화됨."),
              const SizedBox(height: 20),
              _buildSimpleMenu("개인정보 처리방침", isDark),
              _buildSimpleMenu("이용 약관", isDark),
              _buildSimpleMenu("고객 센터", isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingToggle(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool isLightBox = false,
    required bool isDark,
  }) {
    Color bgColor = Colors.white;
    if (isDark) {
      bgColor = isLightBox ? const Color(0xFF2C2C2C) : const Color(0xFF1E1E1E);
    } else {
      bgColor = isLightBox ? const Color(0xFFEEEEF0) : Colors.white;
    }

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: const Color(0xFFB50008)),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbImage: null,
              ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFB50008),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withAlpha(178),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildSimpleMenu(String title, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2C)
            : const Color(0xFFEEEEF0).withAlpha(127),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Icon(
            Icons.open_in_new,
            size: 18,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ],
      ),
    );
  }
}
