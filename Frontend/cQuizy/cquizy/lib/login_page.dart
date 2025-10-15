// lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

// Jelszóerősség-szintek definiálása
enum PasswordStrength { none, weak, medium, strong }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoginView = true;
  final _loginFormKey = GlobalKey<FormBuilderState>();

  // Jelszó láthatóságának állapotai
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  // Regisztrációs folyamat állapotai
  final _pageController = PageController();
  int _currentPage = 0;
  final List<GlobalKey<FormBuilderState>> _formKeys = [
    GlobalKey<FormBuilderState>(),
    GlobalKey<FormBuilderState>(),
    GlobalKey<FormBuilderState>(),
    GlobalKey<FormBuilderState>(),
  ];

  // Regisztrációs adatok ideiglenes tárolása
  final Map<String, dynamic> _registrationData = {};

  // Jelszóerősség és gomb állapot
  PasswordStrength _passwordStrength = PasswordStrength.none;
  bool _isRegisterButtonEnabled = false;

  // BIZTONSÁGI FUNKCIÓK: Megakadályozzák a hibát gyors gombnyomás esetén
  bool _isPageTransitioning = false;
  bool _isSwitchingView = false; // ÚJ GUARD a nézetváltó gombhoz

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _resetRegistrationState() {
    setState(() {
      _currentPage = 0;
      _passwordStrength = PasswordStrength.none;
      _isRegisterButtonEnabled = false;
      _isPageTransitioning = false;
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
      if (score < 3) _passwordStrength = PasswordStrength.weak;
      else if (score < 5) _passwordStrength = PasswordStrength.medium;
      else _passwordStrength = PasswordStrength.strong;
      _updateRegisterButtonState();
    });
  }

  void _updateRegisterButtonState() {
    final formState = _formKeys[3].currentState;
    if (formState == null) return;
    final password = formState.fields['password']?.value;
    final confirmPassword = formState.fields['confirm_password']?.value;
    final bool isStrongEnough = _passwordStrength == PasswordStrength.medium || _passwordStrength == PasswordStrength.strong;
    final bool passwordsMatch = password != null && password.isNotEmpty && password == confirmPassword;
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100;
    final Color fillColor = isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey.shade200;
    final Color hintColor = isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600;
    final Color textColor = isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color primaryColor = const Color(0xFFED2F5B);

    final modernInputDecoration = InputDecoration(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: primaryColor, width: 2)),
      floatingLabelStyle: TextStyle(color: primaryColor),
    );

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: TextButton(
                key: ValueKey<bool>(isLoginView),
                // JAVÍTÁS: Guard a gyors dupla kattintások ellen
                onPressed: () {
                  if (_isSwitchingView) return;

                  setState(() {
                    _isSwitchingView = true; // Gomb lezárása
                    isLoginView = !isLoginView;
                    if (!isLoginView) {
                      _resetRegistrationState();
                    }
                  });

                  // Gomb feloldása az animáció után
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        _isSwitchingView = false;
                      });
                    }
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isLoginView ? 'Regisztráció' : 'Bejelentkezés',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
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
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
                  return FadeTransition(
                    opacity: curvedAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(curvedAnimation),
                      child: child,
                    ),
                  );
                },
                child: isLoginView
                    ? _buildLoginForm(modernInputDecoration, textColor, subTextColor, isDarkMode)
                    : _buildRegisterStepper(modernInputDecoration, textColor, subTextColor, hintColor, isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(InputDecoration decoration, Color textColor, Color subTextColor, bool isDarkMode) {
    return Container(
      key: const ValueKey('loginForm'),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFED2F5B).withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: FormBuilder(
          key: _loginFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo/logo_2.png', height: 100),
              const SizedBox(height: 16),
              Text("Üdvözlünk újra!", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Jelentkezz be a folytatáshoz.", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: subTextColor), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FormBuilderTextField(name: 'username', style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'Felhasználónév', prefixIcon: Icon(Icons.person_outline, color: subTextColor)), validator: FormBuilderValidators.required(errorText: 'A felhasználónév megadása kötelező.')),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'password',
                style: TextStyle(color: textColor),
                obscureText: _isPasswordObscured,
                decoration: decoration.copyWith(labelText: 'Jelszó', prefixIcon: Icon(Icons.lock_outline, color: subTextColor), suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: subTextColor), onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured))),
                validator: FormBuilderValidators.compose([FormBuilderValidators.required(errorText: 'A jelszó megadása kötelező.'), FormBuilderValidators.minLength(6, errorText: 'A jelszónak legalább 6 karakter hosszúnak kell lennie.')]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFFED2F5B), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                onPressed: () {
                  if (_loginFormKey.currentState?.saveAndValidate() ?? false) {
                    debugPrint(_loginFormKey.currentState?.value.toString());
                  }
                },
                child: const Text('Bejelentkezés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterStepper(InputDecoration decoration, Color textColor, Color subTextColor, Color hintColor, bool isDarkMode) {
    const fieldPadding = EdgeInsets.symmetric(horizontal: 5.0);
    final List<Widget> pages = [
      _buildStep("Add meg a neved", "Kérjük, a valós neved add meg.", _formKeys[0], decoration, textColor, subTextColor, [Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'lastName', initialValue: _registrationData['lastName'], style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'Vezetéknév'), validator: FormBuilderValidators.required(errorText: 'Kötelező mező.'))), const SizedBox(height: 16), Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'firstName', initialValue: _registrationData['firstName'], style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'Keresztnév'), validator: FormBuilderValidators.required(errorText: 'Kötelező mező.')))]),
      _buildStep("Azonosítók", "Válassz egyedi azonosítókat.", _formKeys[1], decoration, textColor, subTextColor, [Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'username', initialValue: _registrationData['username'], style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'Felhasználónév'), validator: FormBuilderValidators.required(errorText: 'Kötelező mező.'))), const SizedBox(height: 16), Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'nickname', initialValue: _registrationData['nickname'], style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'Becenév (opcionális)')))]),
      _buildStep("Add meg az e-mail címed", "Ide küldjük az értesítéseket.", _formKeys[2], decoration, textColor, subTextColor, [Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'email', initialValue: _registrationData['email'], style: TextStyle(color: textColor), decoration: decoration.copyWith(labelText: 'E-mail cím'), validator: FormBuilderValidators.compose([FormBuilderValidators.required(errorText: 'Kötelező mező.'), FormBuilderValidators.email(errorText: 'Érvénytelen formátum.')])))]),
      _buildStep("Válassz egy biztonságos jelszót", "Legalább 8 karakter, tartalmazzon kis- és nagybetűt, valamint számot.", _formKeys[3], decoration, textColor, subTextColor, [Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'password', style: TextStyle(color: textColor), obscureText: _isPasswordObscured, onChanged: _checkPasswordStrength, decoration: decoration.copyWith(labelText: 'Jelszó', suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured))))), const SizedBox(height: 8), PasswordStrengthIndicator(strength: _passwordStrength), const SizedBox(height: 8), Padding(padding: fieldPadding, child: FormBuilderTextField(name: 'confirm_password', style: TextStyle(color: textColor), obscureText: _isConfirmPasswordObscured, onChanged: (_) => _updateRegisterButtonState(), decoration: decoration.copyWith(labelText: 'Jelszó újra', suffixIcon: IconButton(icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured))), validator: (val) => (val != _formKeys[3].currentState?.fields['password']?.value) ? 'A két jelszó nem egyezik.' : null))]),
    ];
    return Container(
      key: const ValueKey('registerForm'),
      margin: const EdgeInsets.all(16.0),
      height: 480,
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(24.0), border: Border.all(color: const Color(0xFFED2F5B).withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: (_currentPage + 1) / pages.length, backgroundColor: Colors.grey.shade700, color: const Color(0xFFED2F5B), minHeight: 6),
            const SizedBox(height: 16),
            Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), onPageChanged: (index) => setState(() => _currentPage = index), children: pages)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0) TextButton(onPressed: _isPageTransitioning ? null : _previousPage, child: const Text('Vissza', style: TextStyle(color: Color(0xFFED2F5B)))) else const SizedBox(width: 60),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFFED2F5B), disabledBackgroundColor: Colors.grey.shade800, disabledForegroundColor: Colors.grey.shade400),
                  onPressed: _isPageTransitioning ? null : ((_currentPage == pages.length - 1) ? (_isRegisterButtonEnabled ? () { final currentForm = _formKeys[_currentPage].currentState; if (currentForm != null && currentForm.saveAndValidate()) { _registrationData.addAll(currentForm.value); debugPrint("Regisztrációs adatok: $_registrationData"); } } : null) : _nextPage),
                  child: Text(_currentPage == pages.length - 1 ? 'Regisztráció' : 'Tovább'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String title, String subtitle, GlobalKey<FormBuilderState> key, InputDecoration decoration, Color textColor, Color subTextColor, List<Widget> fields) {
    return SingleChildScrollView(
      child: FormBuilder(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: subTextColor), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ...fields,
          ],
        ),
      ),
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;
  const PasswordStrengthIndicator({super.key, required this.strength});
  Color _getColor(PasswordStrength s) { switch (s) { case PasswordStrength.weak: return Colors.red; case PasswordStrength.medium: return Colors.orange; case PasswordStrength.strong: return Colors.green; default: return Colors.grey.shade300; } }
  String _getText(PasswordStrength s) { switch (s) { case PasswordStrength.weak: return 'Gyenge'; case PasswordStrength.medium: return 'Közepes'; case PasswordStrength.strong: return 'Erős'; default: return 'Jelszó erőssége'; } }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            final int strengthIndex = strength.index;
            return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2.0), height: 6, decoration: BoxDecoration(color: index < strengthIndex ? _getColor(strength) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))));
          }),
        ),
        const SizedBox(height: 4),
        Text(_getText(strength), style: TextStyle(fontSize: 12, color: _getColor(strength))),
      ],
    );
  }
}