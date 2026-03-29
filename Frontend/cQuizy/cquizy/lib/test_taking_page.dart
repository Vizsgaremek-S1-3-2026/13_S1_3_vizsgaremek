import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'api_service.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'utils/web_protections.dart';
import 'home_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:scribble/scribble.dart';

import 'package:provider/provider.dart';
import 'providers/user_provider.dart';

class TestTakingPage extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final String groupName;
  final bool anticheat;
  final bool kiosk;

  const TestTakingPage({
    super.key,
    required this.quiz,
    required this.groupName,
    this.anticheat = false,
    this.kiosk = false,
  });

  @override
  State<TestTakingPage> createState() => _TestTakingPageState();
}

class _TestTakingPageState extends State<TestTakingPage>
    with WidgetsBindingObserver, WindowListener {
  // --- Protection State ---
  bool _isBlacklisted = false;
  bool _isAntiCheatActive = false;
  bool _isSubmitting = false;
  bool _isOffline = false;
  bool _isKioskModeActive = true;
  DateTime? _finishTime;
  Timer? _countdownTimer;
  Timer? _statusPollingTimer;
  double _originalVolume = 1.0;
  StreamSubscription<double>? _volumeSubscription;

  // --- UI/Logic State ---
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  final Map<int, dynamic> _userAnswers = {};
  final Map<int, List<String>> _shuffledOptions = {};
  final ScrollController _scrollController = ScrollController();

  // --- Notepad (scratchpad) for desktop ---
  final TextEditingController _notepadController = TextEditingController();
  bool _isNotepadExpanded = true;
  String _notepadPosition = 'right'; // 'left', 'right', 'bottom'
  double _notepadSize =
      400.0; // Custom size (width for left/right, height for bottom)
  static const double _notepadMinSize = 200.0;
  static const double _notepadMaxSize = 600.0;

  // --- Notepad Tabs ---
  int _notepadTabIndex = 0; // 0 = Jegyzet, 1 = Web, 2 = Kép
  String? _selectedWebUrl;
  String? _selectedImageUrl;
  WebViewController? _webViewController;
  WebviewController? _windowsWebViewController;

  // --- Drawing State ---
  bool _isDrawingMode = false;
  final Map<String, ScribbleNotifier> _imageDrawings = {};

  // --- Question Marking State ---
  final Set<int> _markedQuestions = {};

  // Extract allowed URLs from questions
  List<String> get _allowedUrls {
    final urls = <String>[];
    for (final q in _questions) {
      final url = q['link_url']?.toString();
      if (url != null && url.isNotEmpty) {
        if (!urls.contains(url)) {
          urls.add(url);
        }
      }
    }
    // Fallback/Default for testing
    if (urls.isEmpty) {
      urls.add('https://szbi-pg.hu');
    }
    return urls;
  }

  void _initializeWebView() {
    if (kIsWeb) {
      // WebView nem támogatott weben ebben a formában (külön iframe implementáció kéne)
      return;
    }

    if (Platform.isWindows) {
      final urls = _allowedUrls;
      if (urls.isNotEmpty) {
        _selectedWebUrl = urls.first;
      }
      _initializeWindowsWebView();
      return;
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    final urls = _allowedUrls;
    if (urls.isNotEmpty) {
      _selectedWebUrl = urls.first;
      _webViewController!.loadRequest(Uri.parse(_selectedWebUrl!));
    }
  }

  Future<void> _initializeWindowsWebView() async {
    _windowsWebViewController = WebviewController();
    try {
      await _windowsWebViewController!.initialize();
      await _windowsWebViewController!.setBackgroundColor(Colors.transparent);
      if (_selectedWebUrl != null) {
        await _windowsWebViewController!.loadUrl(_selectedWebUrl!);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Windows WebView hiba: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial API Load
    _loadQuiz();

    // Only enable focus monitoring on desktop platforms
    if (widget.anticheat &&
        !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
    }
    if (widget.kiosk) {
      _enterFullscreen();
    }
    _initializeWebView();
    if (kIsWeb && widget.anticheat) {
      _setupWebProtections();
    }
    if (widget.anticheat) {
      _setupAdvancedProtections();
    } else {
      _initPersistentTimer();
    }
    _initStatusPolling();
  }

  Future<void> _loadQuiz() async {
    final quizId = widget.quiz['id'];
    if (quizId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hiba: Nincs kvíz ID')));
        Navigator.pop(context);
      }
      return;
    }

    final token = context.read<UserProvider>().token;
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hiba: Nincs bejelentkezve')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final api = ApiService();
      final data = await api.startQuiz(token, quizId);

      if (data != null && data['blocks'] != null) {
        final List<dynamic> blocks = data['blocks'];
        if (mounted) {
          if (widget.anticheat) {
            // Várakozás a biztonságos környezet inicializálására (kizárja az azonnali fals tiltásokat)
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              setState(() {
                _isAntiCheatActive = true;
                _questions = blocks.cast<Map<String, dynamic>>();
                _isLoading = false;
              });
              _reportEvent('TEST_START', 'A diák elkezdte a tesztet.');
            }
          } else {
            setState(() {
              _questions = blocks.cast<Map<String, dynamic>>();
              _isLoading = false;
            });
            _reportEvent('TEST_START', 'A diák elkezdte a tesztet.');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hiba a teszt betöltésekor: Üres válasz'),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a teszt betöltésekor: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _enableScreenshotProtection() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await ScreenProtector.protectDataLeakageOn();
      } catch (e) {
        debugPrint('Képernyőkép védelem bekapcsolása sikertelen: $e');
      }
    }
  }

  void _disableScreenshotProtection() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await ScreenProtector.protectDataLeakageOff();
      } catch (e) {
        debugPrint('Képernyőkép védelem kikapcsolása sikertelen: $e');
      }
    }
  }

  void _setupAdvancedProtections() async {
    // 1. Screenshot Protection (Mobile + Desktop)
    _enableScreenshotProtection();

    // 2. Clipboard Protection
    _clearClipboard();

    // 3. Network Monitoring - only notify teacher, don't block student
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        if (!_isOffline) {
          setState(() => _isOffline = true);
          _reportNetworkIssue('disconnected');
        }
      } else {
        if (_isOffline) {
          setState(() => _isOffline = false);
          _reportNetworkIssue('reconnected');
        }
      }
    });

    // 4. Initialize Persistent Timer
    _initPersistentTimer();

    // 5. Keep screen awake during test (not supported on web)
    if (!kIsWeb) {
      WakelockPlus.enable();
    }

    // 6. Mute volume to prevent audio cheating (not supported on web)
    if (!kIsWeb) {
      _muteVolume();
    }

    // 7. Desktop keyboard shortcut blocking
    if (!kIsWeb) {
      _setupDesktopKeyboardProtection();
    }

    // 8. Desktop screen sharing/recording protection
    if (!kIsWeb) {
      _setupDesktopScreenProtection();
    }
  }

  // Block dangerous keyboard shortcuts on desktop
  void _setupDesktopKeyboardProtection() {
    // Use HardwareKeyboard for system-level key detection
    HardwareKeyboard.instance.addHandler(_handleDesktopKeyEvent);
  }

  bool _handleDesktopKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isAltPressed = HardwareKeyboard.instance.isAltPressed;
      final isControlPressed = HardwareKeyboard.instance.isControlPressed;
      final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

      // Block Alt+Tab (attempt - OS may still process it)
      if (isAltPressed && key == LogicalKeyboardKey.tab) {
        _triggerAntiCheat();
        return true; // Consume the event
      }

      // Block Alt+F4
      if (isAltPressed && key == LogicalKeyboardKey.f4) {
        return true; // Consume the event
      }

      // Block Ctrl+Tab (switch tabs)
      if (isControlPressed && key == LogicalKeyboardKey.tab) {
        return true;
      }

      // Block Ctrl+W (close window/tab)
      if (isControlPressed && key == LogicalKeyboardKey.keyW) {
        return true;
      }

      // Block Ctrl+N (new window)
      if (isControlPressed && key == LogicalKeyboardKey.keyN) {
        return true;
      }

      // Block Ctrl+T (new tab)
      if (isControlPressed && key == LogicalKeyboardKey.keyT) {
        return true;
      }

      // Block F5 (refresh)
      if (key == LogicalKeyboardKey.f5) {
        return true;
      }

      // Block Ctrl+R (refresh)
      if (isControlPressed && key == LogicalKeyboardKey.keyR) {
        return true;
      }

      // Block Windows/Meta key
      if (isMetaPressed) {
        _triggerAntiCheat();
        return true;
      }

      // Block PrintScreen
      if (key == LogicalKeyboardKey.printScreen) {
        _triggerAntiCheat();
        return true;
      }
    }
    return false; // Don't consume normal key events
  }

  // Setup desktop screen sharing/recording protection
  void _setupDesktopScreenProtection() async {
    try {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        // On desktop, we use window_manager settings for protection
        // Combined with the screenshot protection, this covers most cases

        // Set window to be always on top to prevent easy switching
        // And prevent window from being minimized during test
        await windowManager.setPreventClose(true);
      }
    } catch (e) {
      debugPrint('Desktop screen protection setup failed: $e');
    }
  }

  void _cleanupDesktopScreenProtection() async {
    try {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        await windowManager.setPreventClose(false);
      }
    } catch (e) {
      debugPrint('Desktop screen protection cleanup failed: $e');
    }
  }

  void _cleanupDesktopKeyboardProtection() {
    if (!kIsWeb) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopKeyEvent);
    }
  }

  void _clearClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (e) {
      debugPrint('Vágólap ürítése sikertelen: $e');
    }
  }

  void _muteVolume() async {
    try {
      // Don't show system UI when changing volume
      VolumeController().showSystemUI = false;

      // Store current volume to restore later
      _originalVolume = await VolumeController().getVolume();

      // Mute the volume
      VolumeController().setVolume(0);

      // Poll for volume changes and reset to 0 if user tries to change
      _volumeSubscription = Stream.periodic(const Duration(milliseconds: 500))
          .asyncMap((_) => VolumeController().getVolume())
          .listen((volume) {
            if (volume > 0 && mounted) {
              VolumeController().setVolume(0);
            }
          });
    } catch (e) {
      debugPrint('Hangerő némítása sikertelen: $e');
    }
  }

  void _restoreVolume() {
    try {
      // Cancel the volume listener
      _volumeSubscription?.cancel();
      _volumeSubscription = null;

      VolumeController().showSystemUI = false;
      VolumeController().setVolume(_originalVolume);
    } catch (e) {
      debugPrint('Hangerő visszaállítása sikertelen: $e');
    }
  }

  // Report network issue to teacher (doesn't block student)
  void _reportNetworkIssue(String issueType) async {
    _reportEvent('network', issueType);
  }

  // Helper to report any event
  Future<void> _reportEvent(String type, String desc) async {
    try {
      final token = context.read<UserProvider>().token;
      final quizId = widget.quiz['id'];

      if (token != null && quizId != null) {
        // Fire and forget
        ApiService().reportEvent(token, {
          'quiz_id': quizId,
          'type': type,
          'desc': desc,
        });
      }
    } catch (e) {
      debugPrint('Esemény jelentése sikertelen: $e');
    }
  }

  void _initPersistentTimer() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'test_finish_time_${widget.quiz['id']}';

    // Check if we already have a finish time stored
    String? storedObfuscated = prefs.getString(key);
    if (storedObfuscated == null) {
      // Use date_end from API as truth
      DateTime finishTime;
      if (widget.quiz['date_end'] != null) {
        finishTime =
            DateTime.tryParse(widget.quiz['date_end'])?.toLocal() ??
            DateTime.now().add(const Duration(minutes: 30));
      } else {
        finishTime = DateTime.now().add(const Duration(minutes: 30));
      }

      final encoded = base64.encode(utf8.encode(finishTime.toIso8601String()));
      await prefs.setString(key, encoded);
      setState(() => _finishTime = finishTime);
    } else {
      try {
        final decoded = utf8.decode(base64.decode(storedObfuscated));
        setState(() => _finishTime = DateTime.parse(decoded));
      } catch (e) {
        // Fallback to API data if local storage is corrupt
        if (widget.quiz['date_end'] != null) {
          _finishTime = DateTime.tryParse(widget.quiz['date_end'])?.toLocal();
        }
        _finishTime ??= DateTime.now().add(const Duration(minutes: 30));
        setState(() {});
      }
    }

    // Start UI update timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Auto-submit if time is up
      if (_finishTime != null && !_isSubmitting) {
        final remaining = _finishTime!.difference(DateTime.now()).inSeconds;
        if (remaining <= 1) {
          // 1 second buffer
          timer.cancel();
          _submitTest(forced: true);
          return;
        }
      }

      setState(() {});
    });
  }

  void _initStatusPolling() {
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await _checkLockStatus();
    });
  }

  Future<void> _checkLockStatus() async {
    if (!mounted || _isSubmitting) return;

    final token = context.read<UserProvider>().token;
    final quizId = widget.quiz['id'];
    if (token == null || quizId == null) return;

    final statusData = await ApiService().checkLockStatus(token, quizId);
    if (statusData == null || !mounted || _isSubmitting) return;

    final isClosed = statusData['is_closed'] == true;
    final isLocked = statusData['is_locked'] == true;
    final activeEventId = statusData['active_event_id'];
    debugPrint('[lock-status] is_locked=$isLocked is_closed=$isClosed active_event_id=$activeEventId');

    if (isClosed) {
      // Tanár lezárta → automatikus beadás
      _statusPollingTimer?.cancel();
      _submitTest(forced: true);
    } else if (isLocked) {
      // Tanár letiltotta → felület zárolása (ha még nincs zárolva)
      if (!_isBlacklisted) {
        setState(() {
          _isBlacklisted = true;
        });
        _reportEvent('STUDENT_CHEAT', 'Tanár általi letiltás.');
      }
    } else if (!isLocked && _isBlacklisted) {
      // Tanár feloldotta → folytatás
      setState(() {
        _isBlacklisted = false;
      });
      // A tanár feloldása már regisztrálva van a szerveren a resolve hívással.
    }
  }



  void _setupWebProtections() {
    WebProtections.setup(() {
      _triggerAntiCheat();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusPollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Cleanup drawings
    for (var notifier in _imageDrawings.values) {
      notifier.dispose();
    }
    _imageDrawings.clear();

    // Only cleanup protections if they were enabled
    if (widget.anticheat) {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        windowManager.removeListener(this);
      }
      _disableScreenshotProtection();
      if (!kIsWeb) {
        WakelockPlus.disable();
      }
      _restoreVolume();
      _cleanupDesktopKeyboardProtection();
      _cleanupDesktopScreenProtection();
    }

    if (widget.kiosk) {
      _exitFullscreen();
    }

    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    try {
      // Mobile fullscreen logic remains same
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Desktop enhancement - Windows
      if (!kIsWeb && Platform.isWindows) {
        await windowManager.setPreventClose(true);
        await windowManager.setAlwaysOnTop(true);

        // Hide title bar for true fullscreen
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

        await windowManager.show();
        await windowManager.focus();
        await windowManager.setFullScreen(true);
      }

      // Mobile kiosk mode with retry mechanism
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _enableKioskModeWithRetry();
      }
      // Web fullscreen
      if (kIsWeb) {
        WebProtections.enterFullScreen();
      }
    } catch (e) {
      debugPrint('Hiba a teljes képernyőre váltáskor: $e');
    }
  }

  /// Kiosk mode with retry - keeps asking user until they enable it natively without blocking Flutter dialogs
  Future<void> _enableKioskModeWithRetry() async {
    // Attempt to start kiosk mode with OS
    await startKioskMode();

    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      final currentMode = await getKioskMode();

      if (currentMode == KioskMode.enabled) {
        if (!_isKioskModeActive) {
          setState(() => _isKioskModeActive = true);
        }
        return; // Success - exit the loop
      } else {
        // Not enabled - show the fullscreen overlay implicitly by updating state
        if (_isKioskModeActive) {
          setState(() => _isKioskModeActive = false);
        }
      }
    }
  }

  Future<void> _exitFullscreen() async {
    try {
      // Web fullscreen reset
      if (kIsWeb) {
        WebProtections.exitFullScreen();
      }

      // Reset Mobile Kiosk
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await stopKioskMode();
      }

      // Reset Mobile UI
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

      // Reset Desktop
      if (!kIsWeb && Platform.isWindows) {
        await windowManager.setPreventClose(false);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        // Give the window manager time to apply changes
        await Future.delayed(const Duration(milliseconds: 200));
      } else if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
        await windowManager.setFullScreen(false);
      }
    } catch (e) {
      debugPrint('Hiba a teljes képernyőből kilépéskor: $e');
    }
  }

  @override
  void onWindowClose() async {
    // Only trigger anti-cheat if protection is enabled (Védett or Zárolt mode)
    if (widget.anticheat) {
      _triggerAntiCheat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only trigger anti-cheat if protection is enabled (Védett or Zárolt mode)
    if (widget.anticheat) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        _triggerAntiCheat();
      }
    }
  }

  // Detect focus loss for desktop (alt-tab)
  @override
  void didChangeMetrics() {
    // This can be used as a fallback for some windowing changes
  }

  void _triggerAntiCheat() {
    // Double-check: only block if anticheat is enabled
    if (!widget.anticheat) return;
    if (!_isAntiCheatActive) return; // Ne kapcsoljon be a betöltés közben
    if (_isSubmitting) return; // Don't re-trigger during submission

    if (!_isBlacklisted) {
      setState(() {
        _isBlacklisted = true;
      });
      _reportEvent('STUDENT_CHEAT', 'Rendszer általi letiltás (Anticheat).');
    }
  }

  String _getFormattedRemainingTime() {
    if (_finishTime == null) return "00:00";
    final remaining = _finishTime!.difference(DateTime.now());
    if (remaining.isNegative) return "00:00";
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateProgress() {
    if (_finishTime == null) return 1.0;
    final totalDuration = const Duration(
      minutes: 30,
    ).inSeconds; // Assuming 30 mins default
    final remaining = _finishTime!.difference(DateTime.now()).inSeconds;
    return (remaining / totalDuration).clamp(0.0, 1.0);
  }

  static const double _maxContentWidth = 800.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Ensure enough space for the hanging number (approx 50px)
    // If margins are large enough (desktop), use standard padding.
    // If margins are small (mobile), force left padding.
    final horizontalMargin = (screenWidth - _maxContentWidth) / 2;
    final needsExtraLeftPadding = horizontalMargin < 60;

    return PopScope(
      canPop: false, // Prevent back button
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!kIsWeb) return KeyEventResult.ignored;

          // Check for DevTools shortcuts (Web only)
          final isControl =
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.f12 ||
              (isControl && isShift && key == LogicalKeyboardKey.keyI) ||
              (isControl && isShift && key == LogicalKeyboardKey.keyJ) ||
              (isControl && isShift && key == LogicalKeyboardKey.keyC) ||
              (isControl && key == LogicalKeyboardKey.keyU)) {
            _triggerAntiCheat();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (event) {
            if (kIsWeb &&
                event.kind == PointerDeviceKind.mouse &&
                event.buttons == kSecondaryMouseButton) {
              // Secondary button (Right Click) detected
            }
          },
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left notepad panel
                      if (screenWidth >= 1200 && _notepadPosition == 'left')
                        _buildNotepadPanel(theme, isHorizontal: true),
                      // Main test content (takes remaining space)
                      Expanded(
                        child: Stack(
                          children: [
                            // 1. Scrollable Questions List or Loading
                            if (_isLoading)
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Biztonságos környezet előkészítése...',
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(
                                  top: 140, // Space for fixed header
                                  bottom: 100, // Space for bottom padding
                                  left: needsExtraLeftPadding ? 60 : 20,
                                  right: 20,
                                ),
                                itemCount: _questions.length,
                                itemBuilder: (context, index) {
                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: _maxContentWidth,
                                      ),
                                      child: _buildQuestionCard(
                                        _questions[index],
                                        index,
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // 2. Fixed Header
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: needsExtraLeftPadding ? 60 : 20,
                                  right: 20,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _maxContentWidth,
                                  ),
                                  child: _buildFixedHeader(theme),
                                ),
                              ),
                            ),

                            // 3. Anti-Cheat Overlay
                            if (_isBlacklisted)
                              Container(
                                color: Colors.black87,
                                child: Center(
                                  child: Container(
                                    margin: const EdgeInsets.all(32),
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Letiltva',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'A felületed zárolva lett, vagy szabálytalan tevékenységet észlelt a rendszer.\nVárd meg a tanári feloldást.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 32),
                                        // Wait for teacher button
                                        OutlinedButton.icon(
                                          onPressed:
                                              null, // Disabled - waiting for teacher
                                          icon: const Icon(
                                            Icons.hourglass_top,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Várakozás a tanári feloldásra...',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Final Submit button
                                        ElevatedButton.icon(
                                          onPressed: () => _submitTest(),
                                          icon: const Icon(Icons.check_circle_outline,
                                              size: 18),
                                          label: const Text('Beadás és kilépés'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            if (!_isKioskModeActive && widget.kiosk)
                              Container(
                                color: Colors.black.withOpacity(0.9),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.fullscreen_exit,
                                        color: Colors.orange,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'Teljes képernyő szükséges!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      ElevatedButton(
                                        onPressed: _enterFullscreen,
                                        child: const Text(
                                          'Vissza a teljes képernyőre',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ), // End of Expanded for Stack
                      // Right notepad panel (desktop only)
                      if (screenWidth >= 1200 && _notepadPosition == 'right')
                        _buildNotepadPanel(theme, isHorizontal: true),
                    ],
                  ), // End of Row
                ), // End of Expanded around Row
                // Bottom notepad panel (always available, only position on mobile)
                if ((screenWidth >= 1200 && _notepadPosition == 'bottom') ||
                    screenWidth < 1200)
                  _buildNotepadPanel(theme, isHorizontal: false),
              ],
            ), // End of Column
          ),
        ),
      ),
    );
  }

  Widget _buildNotepadPanel(ThemeData theme, {required bool isHorizontal}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 1200;

    // Mobile uses smaller default size and limits
    final mobileMinSize = 100.0;
    final mobileMaxSize =
        screenHeight - 180.0; // Leave room for header to avoid overflow
    final mobileDefaultSize = 150.0;

    final collapsedSize = isHorizontal ? 56.0 : 48.0;
    final effectiveSize = isMobile && !isHorizontal
        ? (_notepadSize > mobileMaxSize
              ? mobileMaxSize
              : (_notepadSize < mobileMinSize
                    ? mobileDefaultSize
                    : _notepadSize))
        : _notepadSize;
    final currentSize = _isNotepadExpanded ? effectiveSize : collapsedSize;

    // Resize handle widget
    Widget resizeHandle = MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            if (isHorizontal) {
              final delta = _notepadPosition == 'right'
                  ? -details.delta.dx
                  : details.delta.dx;
              _notepadSize = (_notepadSize + delta).clamp(
                _notepadMinSize,
                _notepadMaxSize,
              );
            } else {
              // Use mobile limits when on mobile
              final minSize = isMobile ? mobileMinSize : _notepadMinSize;
              final maxSize = isMobile ? mobileMaxSize : _notepadMaxSize;
              _notepadSize = (_notepadSize - details.delta.dy).clamp(
                minSize,
                maxSize,
              );
            }
          });
        },
        child: Container(
          width: isHorizontal ? 8 : double.infinity,
          height: isHorizontal ? double.infinity : 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: isHorizontal ? 4 : 50,
              height: isHorizontal ? 50 : 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );

    // Main notepad content
    Widget notepadContent = Container(
      width: isHorizontal ? currentSize : double.infinity,
      height: isHorizontal ? double.infinity : currentSize,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: isHorizontal ? const Offset(-2, 0) : const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isNotepadExpanded
            ? (isHorizontal
                  ? _buildExpandedNotepadVertical(theme)
                  : _buildExpandedNotepadHorizontal(theme))
            : _buildCollapsedNotepad(theme, isHorizontal: isHorizontal),
      ),
    );

    // Collapsed state - no resize handle
    if (!_isNotepadExpanded) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isHorizontal ? collapsedSize : double.infinity,
          height: isHorizontal ? double.infinity : collapsedSize,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildCollapsedNotepad(theme, isHorizontal: isHorizontal),
          ),
        ),
      );
    }

    // Expanded with resize handle
    return Padding(
      padding: const EdgeInsets.all(8),
      child: isHorizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: _notepadPosition == 'right'
                  ? [resizeHandle, notepadContent]
                  : [notepadContent, resizeHandle],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [resizeHandle, notepadContent],
            ),
    );
  }

  Widget _buildExpandedNotepadVertical(ThemeData theme) {
    return Column(
      children: [
        // Clickable Header
        GestureDetector(
          onTap: () => setState(() => _isNotepadExpanded = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jegyzetfüzet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    _buildPositionSelector(theme),
                    Icon(Icons.chevron_right, size: 20, color: theme.hintColor),
                  ],
                ),
                const SizedBox(height: 8),
                // Tabs
                Row(
                  children: [
                    _buildNotepadTab(0, 'Jegyzet', Icons.notes, theme),
                    if (!widget.anticheat)
                      _buildNotepadTab(1, 'Web', Icons.language, theme),
                    if (_selectedImageUrl != null)
                      _buildNotepadTab(2, 'Kép', Icons.image, theme),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Notepad content
        Expanded(child: _buildNotepadContent(theme)),
      ],
    );
  }

  Widget _buildNotepadContent(ThemeData theme) {
    switch (_notepadTabIndex) {
      case 0:
        return _buildNotepadTextField(theme);
      case 1:
        return _buildWebView(theme);
      case 2:
        return _buildImageViewer(theme);
      default:
        return _buildNotepadTextField(theme);
    }
  }

  Widget _buildImageViewer(ThemeData theme) {
    if (_selectedImageUrl == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_search,
              size: 48,
              color: theme.hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nincs kiválasztott kép',
              style: TextStyle(color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Kattints egy kérdésnél a "Kép megjelenítése" gombra',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Get or create ScribbleNotifier for current image
    final currentImageUrl = _selectedImageUrl!;
    if (!_imageDrawings.containsKey(currentImageUrl)) {
      _imageDrawings[currentImageUrl] = ScribbleNotifier();
    }
    final scribbleNotifier = _imageDrawings[currentImageUrl]!;

    return Column(
      children: [
        // Header with drawing toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              Icon(_isDrawingMode ? Icons.draw : Icons.zoom_in, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isDrawingMode
                      ? 'Rajz mód aktív'
                      : 'Kétujjas nagyítás támogatott',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              // Drawing mode toggle
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isDrawingMode = !_isDrawingMode;
                  });
                },
                icon: Icon(
                  _isDrawingMode ? Icons.zoom_in : Icons.draw,
                  size: 14,
                ),
                label: Text(
                  _isDrawingMode ? 'Nagyítás' : 'Rajzolás',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _isDrawingMode
                      ? theme.primaryColor.withOpacity(0.1)
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImageUrl = null;
                    _isDrawingMode = false;
                    if (_notepadTabIndex == 2) _notepadTabIndex = 0;
                  });
                },
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Bezárás', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        // Image viewer with optional drawing
        Expanded(
          child: _isDrawingMode
              ? Stack(
                  children: [
                    // Background image (non-interactive)
                    Center(
                      child: Image.network(
                        currentImageUrl,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.error_outline,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Hiba a kép betöltésekor',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Drawing overlay
                    Scribble(notifier: scribbleNotifier, drawPen: true),
                  ],
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      currentImageUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.error_outline,
                            color: Colors.orange,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Hiba a kép betöltésekor',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Drawing toolbar (only visible in drawing mode)
        if (_isDrawingMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                const Text('Szín:', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                ...[
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                ].map(
                  (color) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        scribbleNotifier.setColor(color);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    scribbleNotifier.clear();
                  },
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Törlés', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNotepadTab(
    int index,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    final isActive = _notepadTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _notepadTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? theme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? theme.primaryColor : theme.hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.primaryColor : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(ThemeData theme) {
    final urls = _allowedUrls;
    return Column(
      children: [
        if (urls.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedWebUrl,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: urls.map((url) {
                      return DropdownMenuItem<String>(
                        value: url,
                        child: Text(
                          url,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedWebUrl = val;
                          if (!kIsWeb && Platform.isWindows) {
                            _windowsWebViewController?.loadUrl(val);
                          } else {
                            _webViewController?.loadRequest(Uri.parse(val));
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: kIsWeb
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.web_asset_off,
                        size: 48,
                        color: theme.hintColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A webes tartalmak megjelenítése a böngészős verzióban nem támogatott.\nKérjük, használd az alkalmazást ezen feladatok megtekintéséhez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ],
                  ),
                )
              : (_webViewController != null || _windowsWebViewController != null
                    ? (Platform.isWindows
                          ? (_windowsWebViewController?.value.isInitialized ??
                                    false
                                ? Webview(_windowsWebViewController!)
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ))
                          : WebViewWidget(controller: _webViewController!))
                    : const Center(child: CircularProgressIndicator())),
        ),
      ],
    );
  }

  Widget _buildExpandedNotepadHorizontal(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1200;

    return Column(
      children: [
        // Clickable Header
        GestureDetector(
          onTap: () => setState(() => _isNotepadExpanded = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Jegyzetfüzet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                // Only show position selector on desktop
                if (!isMobile) _buildPositionSelector(theme),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: theme.hintColor,
                ),
              ],
            ),
          ),
        ),
        // Tabs
        Container(
          height: 40,
          color: theme.primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              _buildNotepadTab(0, 'Jegyzet', Icons.notes, theme),
              if (!widget.anticheat)
                _buildNotepadTab(1, 'Web', Icons.language, theme),
              if (_selectedImageUrl != null)
                _buildNotepadTab(2, 'Kép', Icons.image, theme),
            ],
          ),
        ),
        // Notepad content
        Expanded(child: _buildNotepadContent(theme)),
      ],
    );
  }

  Widget _buildCollapsedNotepad(ThemeData theme, {required bool isHorizontal}) {
    return GestureDetector(
      onTap: () => setState(() => _isNotepadExpanded = true),
      child: Container(
        color: Colors.transparent,
        child: isHorizontal
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, color: theme.primaryColor),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      'Jegyzetfüzet',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Jegyzetfüzet',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 18,
                    color: theme.hintColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPositionSelector(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.dock, size: 18, color: theme.hintColor),
      tooltip: 'Pozíció',
      padding: EdgeInsets.zero,
      onSelected: (pos) => setState(() => _notepadPosition = pos),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'left',
          child: Row(
            children: [
              Icon(
                Icons.border_left,
                size: 18,
                color: _notepadPosition == 'left' ? theme.primaryColor : null,
              ),
              const SizedBox(width: 8),
              const Text('Bal oldal'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'right',
          child: Row(
            children: [
              Icon(
                Icons.border_right,
                size: 18,
                color: _notepadPosition == 'right' ? theme.primaryColor : null,
              ),
              const SizedBox(width: 8),
              const Text('Jobb oldal'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'bottom',
          child: Row(
            children: [
              Icon(
                Icons.border_bottom,
                size: 18,
                color: _notepadPosition == 'bottom' ? theme.primaryColor : null,
              ),
              const SizedBox(width: 8),
              const Text('Alul'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotepadTextField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _notepadController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText:
              'Írj ide jegyzeteket...\n\n(A dolgozat leadásakor törlődik)',
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
        ),
        style: TextStyle(
          fontSize: 13,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildFixedHeader(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Mobile layout - compact with bordered timer box
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer box with border
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.5),
                  width: 2,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 24,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getFormattedRemainingTime(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _calculateProgress(),
                backgroundColor: theme.dividerColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _calculateProgress() < 0.2 ? Colors.red : Colors.orange,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            // Current time and Submit button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final now = DateTime.now();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _buildSubmitButton(theme),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop layout - original horizontal
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Time | Title | Submit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current Time
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  return Row(
                    mainAxisSize: MainAxisSize.min, // Compact
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Quiz Title
              Expanded(
                child: Text(
                  widget.quiz['title'] ?? 'Névtelen Dolgozat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Submit Button
              _buildSubmitButton(theme),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom Row: Countdown Timer Bar
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Hátralévő idő:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getFormattedRemainingTime(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 16),
              // Progress Bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _calculateProgress(),
                    backgroundColor: theme.dividerColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _calculateProgress() < 0.2 ? Colors.red : Colors.orange,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () {
        // Check each question and collect unanswered ones
        List<Map<String, dynamic>> unansweredQuestions = [];
        int questionNumber = 0;

        for (int i = 0; i < _questions.length; i++) {
          final question = _questions[i];
          final type = question['type']?.toString().toLowerCase() ?? '';
          final questionId = question['id'];

          // Skip non-question types
          if (type == 'text_block' || type == 'divider') continue;
          questionNumber++;

          // Ordering and sentence_ordering always have answers (auto-initialized)
          if (type == 'ordering' || type == 'sentence_ordering') {
            continue; // Always accepted
          }

          // Check if user provided an answer
          final answer = _userAnswers[questionId];
          bool hasAnswer = false;

          if (answer != null) {
            switch (type) {
              case 'single':
                hasAnswer = answer is int;
                break;
              case 'multiple':
                hasAnswer = answer is List && answer.isNotEmpty;
                break;
              case 'text':
                hasAnswer = answer is String && answer.trim().isNotEmpty;
                break;
              case 'range':
                hasAnswer = answer is num;
                break;
              case 'matching':
                if (answer is Map && answer.isNotEmpty) {
                  final answers = question['answers'] as List? ?? [];
                  // Check if ALL pairs have non-empty values
                  hasAnswer = answers.every((pair) {
                    final pairId = pair['id']; // Use ID for lookup
                    final userVal = answer[pairId];
                    return userVal != null &&
                        userVal.toString().trim().isNotEmpty;
                  });
                }
                break;
              case 'gap_fill':
                if (answer is Map) {
                  final answers = question['answers'] as List? ?? [];
                  final gapIndices = answers
                      .map((a) => a['gap_index']?.toString())
                      .where((idx) => idx != null)
                      .toSet();
                  hasAnswer =
                      gapIndices.isNotEmpty &&
                      gapIndices.every((idx) {
                        final val = answer[idx];
                        return val != null && val.toString().trim().isNotEmpty;
                      });
                }
                break;
              case 'category':
                if (answer is Map && answer.isNotEmpty) {
                  final items = question['items'] as List? ?? [];
                  // Check if ALL items are categorized
                  hasAnswer = items.every((item) {
                    final itemId = item['id']?.toString();
                    return answer.containsKey(itemId);
                  });
                }
                break;
              default:
                if (answer is String && answer.isNotEmpty)
                  hasAnswer = true;
                else if (answer is List && answer.isNotEmpty)
                  hasAnswer = true;
                else if (answer is Map && answer.isNotEmpty)
                  hasAnswer = true;
                else if (answer is num)
                  hasAnswer = true;
            }
          }

          if (!hasAnswer) {
            final questionText =
                question['question']?.toString() ?? 'Kérdés #$questionNumber';
            final shortText = questionText.length > 40
                ? '${questionText.substring(0, 40)}...'
                : questionText;
            unansweredQuestions.add({
              'number': questionNumber,
              'text': shortText,
              'type': type,
            });
          }
        }

        final hasUnanswered = unansweredQuestions.isNotEmpty;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Dolgozat beadása'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasUnanswered) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${unansweredQuestions.length} hiányzó válasz:',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...unansweredQuestions
                              .take(5)
                              .map(
                                (q) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${q['number']} ',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          q['text'],
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          if (unansweredQuestions.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 8),
                              child: Text(
                                '...és még ${unansweredQuestions.length - 5} további',
                                style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Biztosan be szeretnéd adni a dolgozatot?'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mégse'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitTest();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Beadás'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('Leadás'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Robust submit (fire-and-forget navigation)
  void _submitTest({bool forced = false}) {
    if (!mounted) return;

    _isSubmitting = true;
    _countdownTimer?.cancel();
    _statusPollingTimer?.cancel();

    _reportEvent('TEST_FINISH', 'A diák leadta/befejezte a tesztet.');

    // 1. Format Answers
    final token = context.read<UserProvider>().token;
    if (token != null) {
      final formattedAnswers = <Map<String, dynamic>>[];
      _userAnswers.forEach((key, value) {
        final int blockId = key;
        final Map<String, dynamic> q = _questions.firstWhere(
          (element) => element['id'] == blockId,
          orElse: () => {},
        );
        if (q.isEmpty || value == null) return;

        final String type = q['type'] ?? '';

        if (type == 'single') {
          formattedAnswers.add({
            'block_id': blockId,
            'option_id': value as int,
            'answer_text': '',
          });
        } else if (type == 'multiple') {
          final selectedIds = (value as List).cast<int>();
          for (var id in selectedIds) {
            formattedAnswers.add({
              'block_id': blockId,
              'option_id': id,
              'answer_text': '',
            });
          }
        } else if (type == 'text' || type == 'range') {
          formattedAnswers.add({
            'block_id': blockId,
            'answer_text': value.toString(),
            'option_id': null,
          });
        } else if (type == 'matching') {
          final userMap = (value as Map);
          userMap.forEach((leftId, userString) {
            formattedAnswers.add({
              'block_id': blockId,
              'option_id': leftId,
              'answer_text': userString,
            });
          });
        } else if (type == 'ordering') {
          final orderedItems = (value as List);
          for (var item in orderedItems) {
            formattedAnswers.add({
              'block_id': blockId,
              'option_id': item['id'],
              'answer_text': '',
            });
          }
        } else if (type == 'gap_fill') {
          final gapsMap = (value as Map);
          final sortedKeys = gapsMap.keys.toList()
            ..sort(
              (a, b) =>
                  int.parse(a.toString()).compareTo(int.parse(b.toString())),
            );
          for (var key in sortedKeys) {
            formattedAnswers.add({
              'block_id': blockId,
              'answer_text': gapsMap[key],
              'option_id': null,
            });
          }
        } else if (type == 'sentence_ordering') {
          final words = (value as List).cast<String>();
          for (var word in words) {
            formattedAnswers.add({'block_id': blockId, 'answer_text': word});
          }
        }
      });

      final submissionData = {
        'quiz_id': widget.quiz['id'],
        'answers': formattedAnswers,
      };

      // Fire-and-forget API call
      ApiService().submitQuiz(token, submissionData).catchError((_) => null);
    }

    // 2. Trigger Guaranteed Navigation
    // We use a microtask to ensure the Navigator.pop() from the dialog has time to start
    // while ensuring the UI doesn't hang.
    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (c) => HomePage(
            onLogout: () {
              Provider.of<UserProvider>(c, listen: false).logout();
            },
          ),
        ),
        (route) => false,
      );
    });
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final type = question['type'];

    // For text_block and divider, render without question card styling
    if (type == 'text_block' || type == 'divider') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildQuestionBody(question),
      );
    }

    // Calculate the actual question number (excluding text_block and divider)
    int questionNumber = 0;
    for (int i = 0; i <= index; i++) {
      final t = _questions[i]['type']?.toString().toLowerCase() ?? '';
      if (t != 'text_block' && t != 'divider') {
        questionNumber++;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question Number and Star
        SizedBox(
          width: 50,
          child: Column(
            children: [
              Text(
                '#$questionNumber',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: primaryColor.withOpacity(0.8),
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_markedQuestions.contains(index)) {
                      _markedQuestions.remove(index);
                    } else {
                      _markedQuestions.add(index);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _markedQuestions.contains(index)
                        ? Colors.orange.withOpacity(0.1)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _markedQuestions.contains(index)
                        ? Icons.star
                        : Icons.star_border,
                    color: _markedQuestions.contains(index)
                        ? Colors.orange
                        : Colors.grey.withOpacity(0.5),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Question Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _markedQuestions.contains(index)
                    ? Colors.orange
                    : Colors.transparent,
                width: 2,
              ),
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            question['question'] ?? 'Hiányzó kérdés szöveg',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (question['image_url'] != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImageUrl = question['image_url'];
                            _notepadTabIndex = 2; // Kép tab
                            _isNotepadExpanded = true;
                          });
                        },
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Kép megjelenítése'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Question Body (Dynamic based on type)
                    _buildQuestionBody(question),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBody(Map<String, dynamic> question) {
    switch (question['type']) {
      case 'single':
        return _buildSingleChoice(question);
      case 'multiple':
        return _buildMultipleChoice(question);
      case 'text':
        return _buildTextInput(question);
      case 'matching':
        return _buildMatching(question);
      case 'ordering':
        return _buildOrdering(question);
      case 'gap_fill':
        return _buildGapFill(question);
      case 'range':
        return _buildRangeInput(question);
      case 'sentence_ordering':
        return _buildSentenceOrdering(question);
      case 'text_block':
        return _buildTextBlock(question);
      case 'divider':
        return _buildDivider(question);
      default:
        return Text('Ismeretlen kérdéstípus: ${question['type']}');
    }
  }

  Widget _buildTextBlock(Map<String, dynamic> question) {
    final content = question['maintext']?.toString() ?? '';
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Text(
        content.isEmpty ? 'Szöveg blokk' : content,
        style: TextStyle(
          color: content.isEmpty
              ? theme.hintColor
              : theme.textTheme.bodyLarge?.color,
          fontSize: 15,
          height: 1.5,
          fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildDivider(Map<String, dynamic> question) {
    final content = question['maintext']?.toString() ?? '';
    final theme = Theme.of(context);

    if (content.isEmpty) {
      // Simple divider without text
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: theme.dividerColor, thickness: 1),
      );
    }

    // Divider with label text in the center
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: theme.dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              content,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: theme.dividerColor)),
        ],
      ),
    );
  }

  // --- Question Type Widgets ---

  Widget _buildSingleChoice(Map<String, dynamic> question) {
    return Column(
      children: (question['answers'] as List).map<Widget>((answer) {
        return RadioListTile<int>(
          title: Text(answer['text']),
          value: answer['id'],
          groupValue: _userAnswers[question['id']],
          onChanged: (value) {
            setState(() {
              _userAnswers[question['id']] = value;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildMultipleChoice(Map<String, dynamic> question) {
    final currentAnswers =
        (_userAnswers[question['id']] as List?)?.cast<int>() ?? [];

    return Column(
      children: (question['answers'] as List).map<Widget>((answer) {
        final isSelected = currentAnswers.contains(answer['id']);
        return CheckboxListTile(
          title: Text(answer['text']),
          value: isSelected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                currentAnswers.add(answer['id']);
              } else {
                currentAnswers.remove(answer['id']);
              }
              _userAnswers[question['id']] = currentAnswers;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).primaryColor,
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(Map<String, dynamic> question) {
    final controller = TextEditingController(
      text: _userAnswers[question['id']] as String?,
    );
    // Ensure the cursor stays at the end when rebuilding
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    return TextField(
      controller: controller,
      onChanged: (value) {
        _userAnswers[question['id']] = value;
      },
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: 'Írd ide a választ...',
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
    );
  }

  Widget _buildRangeInput(Map<String, dynamic> question) {
    // For range questions, use a simple text input instead of slider
    // The backend stores correct_value + tolerance, not min/max
    final currentVal = _userAnswers[question['id']]?.toString() ?? '';

    return TextField(
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        // Allow digits, dot, comma (for European decimal), and minus sign
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,\-]')),
      ],
      controller: TextEditingController(text: currentVal)
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: currentVal.length),
        ),
      onChanged: (value) {
        // Normalize comma to dot for parsing (European decimal format)
        final normalizedValue = value.replaceAll(',', '.');
        final parsed = num.tryParse(normalizedValue);
        setState(() {
          _userAnswers[question['id']] = parsed;
        });
      },
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 18,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Írd be a számot...',
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildMatching(Map<String, dynamic> question) {
    // Read from 'answers' (as backend sends answers, not pairs)
    final List pairs = (question['answers'] as List?) ?? [];

    // User answers map: { pair_id : user_text_input }
    // We cast to Map<dynamic, dynamic> to handle potential int/string key issues safely
    final userMap = (_userAnswers[question['id']] as Map?) ?? {};

    return Column(
      children: pairs.map<Widget>((pair) {
        final String leftTxt = pair['text']?.toString() ?? '';
        final int pairId = pair['id']; // We MUST use this ID as the key

        // Retrieve answer using the ID, not the Text
        final String? selectedRight = userMap[pairId];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  leftTxt,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_right_alt, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: TextEditingController(text: selectedRight)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: selectedRight?.length ?? 0),
                    ),
                  decoration: InputDecoration(
                    hintText: "Írd be a választ...",
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (_userAnswers[question['id']] == null ||
                          _userAnswers[question['id']] is! Map) {
                        _userAnswers[question['id']] = {};
                      }

                      // CRITICAL FIX: Use pairId (int) as the key, NOT the text
                      final newMap = Map<dynamic, dynamic>.from(
                        _userAnswers[question['id']],
                      );
                      newMap[pairId] = val;
                      _userAnswers[question['id']] = newMap;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrdering(Map<String, dynamic> question) {
    // Initialize items if not yet in userAnswers
    List<dynamic> currentOrder;
    if (_userAnswers[question['id']] == null) {
      currentOrder = List.from(question['answers']);
      if (currentOrder.length > 1) {
        final original = List.from(question['answers']);
        bool hasMatch = true;
        int attempts = 0;

        while (hasMatch && attempts < 20) {
          currentOrder.shuffle();
          hasMatch = false; // Assume success initially

          for (int i = 0; i < currentOrder.length; i++) {
            // If ANY item matches its original position, we must reshuffle
            if (currentOrder[i]['id'] == original[i]['id']) {
              hasMatch = true;
              break;
            }
          }
          attempts++;
        }
      }
      _userAnswers[question['id']] = currentOrder;
    } else {
      currentOrder = _userAnswers[question['id']] as List<dynamic>;
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false, // Enable custom drag listeners
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = currentOrder.removeAt(oldIndex);
          currentOrder.insert(newIndex, item);
          _userAnswers[question['id']] = currentOrder;
        });
      },
      children: [
        for (int i = 0; i < currentOrder.length; i++)
          ReorderableDragStartListener(
            key: ValueKey(currentOrder[i]['id']),
            index: i,
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Theme.of(context).cardColor,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8, // More padding for touch targets
                ),
                leading: Icon(
                  Icons.drag_indicator,
                  color: Theme.of(context).disabledColor,
                ),
                title: Text(
                  currentOrder[i]['text'],
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: Text(
                  "${i + 1}.",
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategory(Map<String, dynamic> question) {
    final categories = List<String>.from(question['categories']);
    final items = List<Map<String, dynamic>>.from(question['items']);
    final userAssignment = (_userAnswers[question['id']] as Map?) ?? {};
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate bucket width based on screen size
    final bucketWidth = screenWidth < 400 ? (screenWidth - 80) / 2 : 180.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Buckets
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: categories.map((cat) {
            final itemsInCat = items
                .where((i) => userAssignment[i['id']] == cat)
                .toList();

            return DragTarget<String>(
              onWillAccept: (data) => true,
              onAccept: (itemId) {
                setState(() {
                  if (_userAnswers[question['id']] == null ||
                      _userAnswers[question['id']] is! Map) {
                    _userAnswers[question['id']] = {};
                  }
                  final newMap = Map<String, dynamic>.from(
                    _userAnswers[question['id']],
                  );
                  newMap[itemId] = cat;
                  _userAnswers[question['id']] = newMap;
                });
              },
              builder: (context, candidates, projects) {
                final isHovered = candidates.isNotEmpty;
                return Container(
                  width: bucketWidth,
                  constraints: const BoxConstraints(minHeight: 140),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHovered ? primaryColor : theme.dividerColor,
                      width: isHovered ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isHovered
                            ? primaryColor.withOpacity(0.2)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: isHovered ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Category Header with gradient
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(isHovered ? 0.3 : 0.15),
                              primaryColor.withOpacity(isHovered ? 0.15 : 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Text(
                          cat,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isHovered
                                ? primaryColor
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      // Items in bucket
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: itemsInCat.isEmpty
                            ? Container(
                                height: 60,
                                alignment: Alignment.center,
                                child: Text(
                                  'Üres',
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: itemsInCat.map((item) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final newMap =
                                            Map<String, dynamic>.from(
                                              _userAnswers[question['id']],
                                            );
                                        newMap.remove(item['id']);
                                        _userAnswers[question['id']] = newMap;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item['text'],
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.close,
                                            size: 14,
                                            color: primaryColor.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        // Item Pool Label
        Row(
          children: [
            Icon(Icons.touch_app, size: 18, color: theme.hintColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Húzd a megfelelő kategóriába:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Item Pool (only unassigned items)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .where((i) => !userAssignment.containsKey(i['id']))
              .map((item) {
                return Draggable<String>(
                  data: item['id'],
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        item['text'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        item['text'],
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      item['text'],
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSentenceOrdering(Map<String, dynamic> question) {
    // Current sentence constructed
    final List<String> constructed =
        (_userAnswers[question['id']] as List?)?.cast<String>() ?? [];

    // Initialize stable shuffled pool if not present
    if (!_shuffledOptions.containsKey(question['id'])) {
      final answersList = question['answers'] as List? ?? [];
      final words = answersList.map((a) => a['text'].toString()).toList();
      words.shuffle(); // Shuffle once
      _shuffledOptions[question['id']] = words;
    }

    final allWords = _shuffledOptions[question['id']]!;
    // Available = All - Constructed
    // We iterate through valid 'allWords' and skip those that are in 'constructed'
    // To handle duplicates correctly, we need to count used instances.
    final available = <String>[];
    final constructedCounts = <String, int>{};
    for (var w in constructed) {
      constructedCounts[w] = (constructedCounts[w] ?? 0) + 1;
    }

    for (var w in allWords) {
      if ((constructedCounts[w] ?? 0) > 0) {
        constructedCounts[w] = constructedCounts[w]! - 1;
      } else {
        available.add(w);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Constructed Area - Now with drag-drop reordering
        Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor.withOpacity(0.5),
          ),
          child: constructed.isEmpty
              ? Center(
                  child: Text(
                    'Húzd ide a szavakat...',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 0,
                  runSpacing: 8,
                  children: [
                    // Each word is draggable and is also a drop target for reordering
                    for (int i = 0; i < constructed.length; i++)
                      DragTarget<int>(
                        onWillAccept: (fromIndex) =>
                            fromIndex != null && fromIndex != i,
                        onAccept: (fromIndex) {
                          setState(() {
                            final newList = List<String>.from(constructed);
                            final word = newList.removeAt(fromIndex);
                            final insertAt = fromIndex < i ? i - 1 : i;
                            newList.insert(insertAt < 0 ? 0 : insertAt, word);
                            _userAnswers[question['id']] = newList;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovered = candidateData.isNotEmpty;
                          return Container(
                            margin: EdgeInsets.only(left: isHovered ? 4 : 0),
                            padding: EdgeInsets.only(left: isHovered ? 8 : 0),
                            decoration: BoxDecoration(
                              border: isHovered
                                  ? Border(
                                      left: BorderSide(
                                        color: Theme.of(context).primaryColor,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Draggable<int>(
                              data: i,
                              feedback: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(20),
                                child: Chip(
                                  label: Text(constructed[i]),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: Chip(
                                  label: Text(constructed[i]),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                ),
                              ),
                              child: Chip(
                                label: Text(constructed[i]),
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    final newList = List<String>.from(
                                      constructed,
                                    );
                                    newList.removeAt(i);
                                    _userAnswers[question['id']] = newList;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    // Drop zone at the END
                    DragTarget<int>(
                      onWillAccept: (fromIndex) =>
                          fromIndex != null &&
                          fromIndex != constructed.length - 1,
                      onAccept: (fromIndex) {
                        setState(() {
                          final newList = List<String>.from(constructed);
                          final word = newList.removeAt(fromIndex);
                          newList.add(word); // Add to end
                          _userAnswers[question['id']] = newList;
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        // Completely invisible - large hit area, no visual feedback
                        return const SizedBox(width: 40, height: 40);
                      },
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        // Word Bank
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available.map((word) {
            return ActionChip(
              label: Text(word),
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide(color: Theme.of(context).dividerColor),
              onPressed: () {
                setState(() {
                  final newList = List<String>.from(constructed);
                  newList.add(word);
                  _userAnswers[question['id']] = newList;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGapFill(Map<String, dynamic> question) {
    // Text: "Aaa {1} bbb {2}."
    // Normalize whitespace: replace newlines and multiple spaces with single space
    final text = (question['gap_text'] as String)
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split text by regex \{(\d+)\}
    final parts = <Widget>[];
    final regex = RegExp(r'\{(\d+)\}');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              text.substring(lastEnd, match.start),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        );
      }

      final gapId = match.group(1)!; // "1", "2"
      final currentAnswer = (_userAnswers[question['id']] as Map?)?[gapId];

      parts.add(
        SizedBox(
          width: 120, // Fixed width for inline input
          child: TextField(
            controller: TextEditingController(text: currentAnswer)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: currentAnswer?.length ?? 0),
              ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '($gapId)',
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                if (_userAnswers[question['id']] == null ||
                    _userAnswers[question['id']] is! Map) {
                  _userAnswers[question['id']] = {};
                }
                final newMap = Map<String, dynamic>.from(
                  _userAnswers[question['id']],
                );
                newMap[gapId] = val;
                _userAnswers[question['id']] = newMap;
              });
            },
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      parts.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            text.substring(lastEnd),
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      );
    }

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _buildWatermarkOverlay() {
    // Watermark disabled
    return const SizedBox.shrink();
  }
}
