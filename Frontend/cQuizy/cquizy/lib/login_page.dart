// lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'api_service.dart'; // Importáljuk az API szolgáltatást

// Jelszóerősség-szintek definiálása
enum PasswordStrength { none, weak, medium, strong }

class LoginPage extends StatefulWidget {
  final VoidCallback
  onLoginSuccess; // Callback a sikeres bejelentkezés jelzésére

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // --- KÖNNYEN SZERKESZTHETŐ KONFIGURÁCIÓ ---

  // 1. Avatarok és kategóriák listája
  static const List<Map<String, dynamic>> _avatars = [
    {
      'id': 'avatar_1',
      'category': 'Figurák',
      'icon': Icons.person_outline,
      'color': Colors.blueGrey,
    },
    {
      'id': 'avatar_2',
      'category': 'Figurák',
      'icon': Icons.face,
      'color': Colors.cyan,
    },
    {
      'id': 'avatar_3',
      'category': 'Figurák',
      'icon': Icons.smart_toy_outlined,
      'color': Colors.orangeAccent,
    },
    {
      'id': 'avatar_4',
      'category': 'Figurák',
      'icon': Icons.child_care,
      'color': Colors.pinkAccent,
    },
    {
      'id': 'avatar_5',
      'category': 'Figurák',
      'icon': Icons.catching_pokemon,
      'color': Colors.red,
    },
    {
      'id': 'avatar_6',
      'category': 'Figurák',
      'icon': Icons.eco_outlined,
      'color': Colors.lightGreen,
    },
    {
      'id': 'avatar_7',
      'category': 'Figurák',
      'icon': Icons.park_outlined,
      'color': Colors.green,
    },
    {
      'id': 'avatar_11',
      'category': 'Szimbólumok',
      'icon': Icons.science_outlined,
      'color': Colors.purple,
    },
    {
      'id': 'avatar_12',
      'category': 'Szimbólumok',
      'icon': Icons.sports_esports_outlined,
      'color': Colors.teal,
    },
    {
      'id': 'avatar_13',
      'category': 'Szimbólumok',
      'icon': Icons.rocket_launch_outlined,
      'color': Colors.deepOrange,
    },
    {
      'id': 'avatar_14',
      'category': 'Szimbólumok',
      'icon': Icons.music_note_outlined,
      'color': Colors.lightBlue,
    },
    {
      'id': 'avatar_15',
      'category': 'Szimbólumok',
      'icon': Icons.brush_outlined,
      'color': Colors.deepPurpleAccent,
    },
    {
      'id': 'avatar_16',
      'category': 'Szimbólumok',
      'icon': Icons.shield_outlined,
      'color': Colors.blue,
    },
    {
      'id': 'avatar_17',
      'category': 'Szimbólumok',
      'icon': Icons.favorite_border,
      'color': Colors.redAccent,
    },
  ];

  // 2. Színpaletta
  // static const _primaryColor = Color(0xFFED2F5B); // Use Theme.of(context).primaryColor instead

  // --- BELSŐ ÁLLAPOTVÁLTOZÓK ---

  final ApiService _apiService =
      ApiService(); // API szolgáltatás példányosítása
  bool _isLoading = false; // Töltési állapot figyelése

  bool isLoginView = true;
  final _loginFormKey = GlobalKey<FormBuilderState>();
  final List<GlobalKey<FormBuilderState>> _formKeys = List.generate(
    5,
    (_) => GlobalKey<FormBuilderState>(),
  );
  final _pageController = PageController();

  int _currentPage = 0;
  bool _isPageTransitioning = false;
  bool _isSwitchingView = false;

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  PasswordStrength _passwordStrength = PasswordStrength.none;
  bool _isRegisterButtonEnabled = false;

  late TabController _avatarTabController;
  String _selectedAvatarId = 'avatar_1';
  String _currentPassword = '';

  final Map<String, dynamic> _registrationData = {};

  @override
  void initState() {
    super.initState();
    final categories = _avatars
        .map((a) => a['category'] as String)
        .toSet()
        .toList();
    _avatarTabController = TabController(
      length: categories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _avatarTabController.dispose();
    super.dispose();
  }

  // --- API HÍVÁSOK ÉS KEZELÉSÜK ---

  void _handleLogin() async {
    final form = _loginFormKey.currentState;
    if (form == null || !form.saveAndValidate()) return;

    setState(() => _isLoading = true);

    final values = form.value;
    final token = await _apiService.login(
      values['username'],
      values['password'],
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (token != null) {
        widget.onLoginSuccess(); // Sikeres bejelentkezés jelzésére
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sikertelen bejelentkezés. Ellenőrizd az adataidat!'),
          ),
        );
      }
    }
  }

  void _handleRegister() async {
    _registrationData['avatar_id'] = _selectedAvatarId;
    debugPrint("Regisztrációs adatok küldése: $_registrationData");

    setState(() => _isLoading = true);

    final success = await _apiService.register(_registrationData);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sikeres regisztráció! Most már bejelentkezhetsz.'),
          ),
        );
        setState(() => isLoginView = true);
        _resetRegistrationState();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A regisztráció sikertelen. Lehet, hogy a felhasználónév vagy e-mail már foglalt.',
            ),
          ),
        );
      }
    }
  }

  // --- ÁLLAPOTKEZELŐ FÜGGVÉNYEK ---

  void _resetRegistrationState() {
    setState(() {
      _currentPage = 0;
      _passwordStrength = PasswordStrength.none;
      _isRegisterButtonEnabled = false;
      _isPageTransitioning = false;
      _selectedAvatarId = 'avatar_1';
      if (_avatarTabController.index != 0) {
        _avatarTabController.animateTo(0);
      }
    });
    _registrationData.clear();
    for (final key in _formKeys) {
      key.currentState?.reset();
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _checkPasswordStrength(String? password) {
    setState(() {
      _currentPassword = password ?? '';
    });
    if (password == null || password.isEmpty) {
      setState(() => _passwordStrength = PasswordStrength.none);
      return;
    }
    double score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    setState(() {
      if (score < 3)
        _passwordStrength = PasswordStrength.weak;
      else if (score < 5)
        _passwordStrength = PasswordStrength.medium;
      else
        _passwordStrength = PasswordStrength.strong;
      _updateRegisterButtonState();
    });
  }

  void _updateRegisterButtonState() {
    final formState = _formKeys[3].currentState;
    if (formState == null) return;
    final password = formState.fields['password']?.value;
    final confirmPassword = formState.fields['confirm_password']?.value;
    final isStrongEnough =
        _passwordStrength == PasswordStrength.medium ||
        _passwordStrength == PasswordStrength.strong;
    final passwordsMatch =
        password != null && password.isNotEmpty && password == confirmPassword;
    setState(() {
      _isRegisterButtonEnabled = isStrongEnough && passwordsMatch;
    });
  }

  void _nextPage() async {
    if (_isPageTransitioning) return;
    final currentForm = _formKeys[_currentPage].currentState;
    if (currentForm != null && currentForm.saveAndValidate()) {
      _registrationData.addAll(currentForm.value);
      setState(() => _isPageTransitioning = true);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _isPageTransitioning = false);
    }
  }

  void _previousPage() async {
    if (_isPageTransitioning) return;
    setState(() => _isPageTransitioning = true);
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _isPageTransitioning = false);
  }

  // --- UI ÉPÍTŐ METÓDUSOK ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final modernInputDecoration = InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surface, // Was colors['fill']
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18.0,
        horizontal: 20.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: primaryColor),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(isDarkMode, theme.scaffoldBackgroundColor),
      body: Stack(
        children: [
          _buildBackgroundWave(context),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final curvedAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  );
                  return FadeTransition(
                    opacity: curvedAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.2),
                        end: Offset.zero,
                      ).animate(curvedAnimation),
                      child: child,
                    ),
                  );
                },
                child: isLoginView
                    ? _buildLoginForm(modernInputDecoration)
                    : _buildRegisterStepper(modernInputDecoration),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDarkMode, Color scaffoldColor) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: scaffoldColor,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        // Ez biztosítja, hogy az állapotsáv ikonjai láthatóak legyenek az app bar színén.
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      actions: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
            child: TextButton(
              key: ValueKey<bool>(isLoginView),
              onPressed: () {
                if (_isSwitchingView || _isLoading) return;
                setState(() {
                  _isSwitchingView = true;
                  isLoginView = !isLoginView;
                  if (!isLoginView) _resetRegistrationState();
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _isSwitchingView = false);
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isLoginView ? 'Regisztráció' : 'Bejelentkezés',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildBackgroundWave(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: WaveWidget(
          config: CustomConfig(
            gradients: [
              [primaryColor.withOpacity(0.5), primaryColor.withOpacity(0.3)],
              [primaryColor.withOpacity(0.4), primaryColor.withOpacity(0.2)],
              [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.3)],
            ],
            durations: [19440, 10800],
            heightPercentages: [0.20, 0.23],
            blur: const MaskFilter.blur(BlurStyle.solid, 10),
            gradientBegin: Alignment.bottomLeft,
            gradientEnd: Alignment.topRight,
          ),
          waveAmplitude: 0,
          size: const Size(double.infinity, double.infinity),
        ),
      ),
    );
  }

  Widget _buildLoginForm(InputDecoration decoration) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    return Container(
      key: const ValueKey('loginForm'),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: FormBuilder(
          key: _loginFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/logo/logo_2.png', height: 100),
                const SizedBox(height: 16),
                Text(
                  "Üdvözlünk újra!",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Jelentkezz be a folytatáshoz.",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FormBuilderTextField(
                  name: 'username',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: decoration.copyWith(
                    labelText: 'Felhasználónév',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: theme.iconTheme.color,
                    ),
                  ),
                  validator: FormBuilderValidators.required(
                    errorText: 'A felhasználónév megadása kötelező.',
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'password',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  obscureText: _isPasswordObscured,
                  decoration: decoration.copyWith(
                    labelText: 'Jelszó',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: theme.iconTheme.color,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: theme.iconTheme.color,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordObscured = !_isPasswordObscured,
                      ),
                    ),
                  ),
                  validator: FormBuilderValidators.required(
                    errorText: 'A jelszó megadása kötelező.',
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Bejelentkezés',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterStepper(InputDecoration decoration) {
    const fieldPadding = EdgeInsets.symmetric(horizontal: 5.0);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    final primaryColor = theme.primaryColor;

    final step5Fields = [_buildAvatarSelector(textColor!)];

    final List<Widget> pages = [
      _buildStep(
        "Add meg a neved",
        "Kérjük, a valós neved add meg.",
        _formKeys[0],
        [
          Padding(
            padding: fieldPadding,
            child: FormBuilderTextField(
              name: 'lastName',
              initialValue: _registrationData['lastName'],
              style: TextStyle(color: textColor),
              decoration: decoration.copyWith(labelText: 'Vezetéknév'),
              validator: FormBuilderValidators.required(
                errorText: 'Kötelező mező.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: fieldPadding,
            child: FormBuilderTextField(
              name: 'firstName',
              initialValue: _registrationData['firstName'],
              style: TextStyle(color: textColor),
              decoration: decoration.copyWith(labelText: 'Keresztnév'),
              validator: FormBuilderValidators.required(
                errorText: 'Kötelező mező.',
              ),
              onSubmitted: (_) => _nextPage(),
            ),
          ),
        ],
      ),
      _buildStep("Azonosítók", "Válassz egyedi azonosítókat.", _formKeys[1], [
        Padding(
          padding: fieldPadding,
          child: FormBuilderTextField(
            name: 'username',
            initialValue: _registrationData['username'],
            style: TextStyle(color: textColor),
            decoration: decoration.copyWith(labelText: 'Felhasználónév'),
            validator: FormBuilderValidators.required(
              errorText: 'Kötelező mező.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: fieldPadding,
          child: FormBuilderTextField(
            name: 'nickname',
            initialValue: _registrationData['nickname'],
            style: TextStyle(color: textColor),
            decoration: decoration.copyWith(labelText: 'Becenév (opcionális)'),
            onSubmitted: (_) => _nextPage(),
          ),
        ),
      ]),
      _buildStep(
        "Add meg az e-mail címed",
        "Ide küldjük az értesítéseket.",
        _formKeys[2],
        [
          Padding(
            padding: fieldPadding,
            child: FormBuilderTextField(
              name: 'email',
              initialValue: _registrationData['email'],
              style: TextStyle(color: textColor),
              decoration: decoration.copyWith(labelText: 'E-mail cím'),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(errorText: 'Kötelező mező.'),
                FormBuilderValidators.email(errorText: 'Érvénytelen formátum.'),
              ]),
              onSubmitted: (_) => _nextPage(),
            ),
          ),
        ],
      ),
      _buildStep(
        "Válassz egy biztonságos jelszót",
        "Legalább 8 karakter, tartalmazzon kis- és nagybetűt, valamint számot.",
        _formKeys[3],
        [
          Padding(
            padding: fieldPadding,
            child: FormBuilderTextField(
              name: 'password',
              style: TextStyle(color: textColor),
              obscureText: _isPasswordObscured,
              onChanged: _checkPasswordStrength,
              decoration: decoration.copyWith(
                labelText: 'Jelszó',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordObscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: hintColor,
                  ),
                  onPressed: () => setState(
                    () => _isPasswordObscured = !_isPasswordObscured,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PasswordStrengthIndicator(strength: _passwordStrength),
          const SizedBox(height: 8),
          PasswordRequirements(password: _currentPassword),
          const SizedBox(height: 8),
          Padding(
            padding: fieldPadding,
            child: FormBuilderTextField(
              name: 'confirm_password',
              style: TextStyle(color: textColor),
              obscureText: _isConfirmPasswordObscured,
              onChanged: (_) => _updateRegisterButtonState(),
              decoration: decoration.copyWith(
                labelText: 'Jelszó újra',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordObscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: hintColor,
                  ),
                  onPressed: () => setState(
                    () => _isConfirmPasswordObscured =
                        !_isConfirmPasswordObscured,
                  ),
                ),
              ),
              validator: (val) =>
                  (val != _formKeys[3].currentState?.fields['password']?.value)
                  ? 'A két jelszó nem egyezik.'
                  : null,
              onSubmitted: (_) {
                if (_isRegisterButtonEnabled) _nextPage();
              },
            ),
          ),
        ],
      ),
      _buildStep(
        "Válassz egy karaktert!",
        "Ez lesz a profilképed. Később is megváltoztathatod.",
        _formKeys[4],
        step5Fields,
      ),
    ];

    return Container(
      key: const ValueKey('registerForm'),
      margin: const EdgeInsets.all(16.0),
      height: 540,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / pages.length,
              backgroundColor: Colors.grey.shade300,
              color: primaryColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _isPageTransitioning || _isLoading
                        ? null
                        : _previousPage,
                    child: Text(
                      'Vissza',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                  )
                else
                  const SizedBox(width: 60),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: theme.primaryColor,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  onPressed: _isPageTransitioning || _isLoading
                      ? null
                      : (_currentPage == pages.length - 1)
                      ? _handleRegister
                      : (_currentPage == pages.length - 2)
                      ? (_isRegisterButtonEnabled ? _nextPage : null)
                      : _nextPage,
                  child: _isLoading && _currentPage == pages.length - 1
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _currentPage == pages.length - 1
                              ? 'Regisztráció'
                              : 'Tovább',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSelector(Color textColor) {
    final theme = Theme.of(context);
    final pageController = PageController(viewportFraction: 0.6);
    final categories = _avatars
        .map((a) => a['category'] as String)
        .toSet()
        .toList();

    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _avatarTabController,
            indicatorColor: theme.primaryColor,
            labelColor: textColor,
            unselectedLabelColor: Colors.grey,
            tabAlignment: TabAlignment.fill,
            tabs: categories.map((c) => Tab(text: c)).toList(),
            onTap: (index) {
              final category = categories[index];
              final firstIndexInCategory = _avatars.indexWhere(
                (a) => a['category'] == category,
              );
              if (firstIndexInCategory != -1) {
                pageController.animateToPage(
                  firstIndexInCategory,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: _avatars.length,
              itemBuilder: (context, index) {
                final avatar = _avatars[index];
                final isSelected = _selectedAvatarId == avatar['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatarId = avatar['id']);
                    pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.transparent,
                            width: 4,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: avatar['color'],
                          child: Icon(
                            avatar['icon'],
                            color: Colors.white,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              onPageChanged: (index) {
                final category = _avatars[index]['category'] as String;
                final categoryIndex = categories.indexOf(category);
                if (categoryIndex != -1 &&
                    _avatarTabController.index != categoryIndex) {
                  _avatarTabController.animateTo(categoryIndex);
                }
                setState(
                  () => _selectedAvatarId = _avatars[index]['id'] as String,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    String title,
    String subtitle,
    GlobalKey<FormBuilderState> key,
    List<Widget> children,
  ) {
    final hasExpanded = children.any((w) => w is Expanded);
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (hasExpanded)
          Expanded(child: Column(children: children))
        else
          ...children,
      ],
    );

    if (!hasExpanded) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }

    return FormBuilder(
      key: key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: content,
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;
  const PasswordStrengthIndicator({super.key, required this.strength});
  Color _getColor(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
      default:
        return Colors.grey.shade300;
    }
  }

  String _getText(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return 'Gyenge';
      case PasswordStrength.medium:
        return 'Közepes';
      case PasswordStrength.strong:
        return 'Erős';
      default:
        return 'Jelszó erőssége';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                height: 6,
                decoration: BoxDecoration(
                  color: index < strength.index
                      ? _getColor(strength)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getText(strength),
          style: TextStyle(fontSize: 12, color: _getColor(strength)),
        ),
      ],
    );
  }
}

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);

    return Column(
      children: [
        _buildRequirement(hasMinLength, 'Legalább 8 karakter'),
        _buildRequirement(hasUppercase, 'Nagybetű'),
        _buildRequirement(hasLowercase, 'Kisbetű'),
        _buildRequirement(hasDigit, 'Szám'),
      ],
    );
  }

  Widget _buildRequirement(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            color: met ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
