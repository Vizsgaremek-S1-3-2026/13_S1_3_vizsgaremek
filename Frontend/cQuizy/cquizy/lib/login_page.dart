// lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoginView = true;
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPasswordObscured = true;

  @override
  Widget build(BuildContext context) {
    // Ellenőrizzük, hogy a jelenlegi téma sötét-e.
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Dinamikus színek a téma alapján.
    final Color scaffoldBackgroundColor =
        isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100;
    final Color fillColor =
        isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey.shade200;
    final Color hintColor =
        isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600;
    final Color textColor =
        isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87;
    final Color subTextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color primaryColor = const Color(0xFFED2F5B);

    final modernInputDecoration = InputDecoration(
      filled: true,
      fillColor: fillColor, // Dinamikus kitöltőszín
      contentPadding:
          const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
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
      backgroundColor: scaffoldBackgroundColor, // Dinamikus háttérszín
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
                onPressed: () {
                  setState(() {
                    isLoginView = !isLoginView;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFED2F5B),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLoginView ? 'Regisztráció' : 'Bejelentkezés',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack( // A Stack visszakerült a hullámok miatt
        children: [
          // A HULLÁM ANIMÁCIÓ A HÁTTÉRBEN
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: WaveWidget(
                config: CustomConfig(
                  gradients: [
                    [
                      primaryColor.withOpacity(0.5),
                      primaryColor.withOpacity(0.3)
                    ],
                    [
                      primaryColor.withOpacity(0.4),
                      primaryColor.withOpacity(0.2)
                    ],
                  ],
                  durations: [19440, 10800],
                  heightPercentages: [0.20, 0.23], // Kicsit alacsonyabb hullámok
                  blur: const MaskFilter.blur(BlurStyle.solid, 10),
                  gradientBegin: Alignment.bottomLeft,
                  gradientEnd: Alignment.topRight,
                ),
                waveAmplitude: 0,
                size: const Size(double.infinity, double.infinity),
              ),
            ),
          ),
          // A KÖZÉPRE IGAZÍTOTT TARTALOM
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isLoginView
                    ? _buildLoginForm(modernInputDecoration, hintColor,
                        textColor, subTextColor, isDarkMode)
                    : _buildRegisterPrompt(
                        textColor, subTextColor, isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(InputDecoration decoration, Color hintColor,
      Color textColor, Color subTextColor, bool isDarkMode) {
    // A kerettel ellátott doboz
    return Container(
      key: const ValueKey('loginForm'),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFED2F5B).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.network(
                'https://www.nicepng.com/png/detail/304-3049649_badge-vintage-png-blank-vintage-logo-template-png.png',
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                "Üdvözlünk újra!",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Jelentkezz be a folytatáshoz.",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: subTextColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FormBuilderTextField(
                name: 'username',
                style: TextStyle(color: textColor),
                decoration: decoration.copyWith(
                  labelText: 'Felhasználónév',
                  prefixIcon: Icon(Icons.person_outline, color: subTextColor),
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                      errorText: 'A felhasználónév megadása kötelező.'),
                ]),
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'password',
                style: TextStyle(color: textColor),
                obscureText: _isPasswordObscured,
                decoration: decoration.copyWith(
                  labelText: 'Jelszó',
                  prefixIcon: Icon(Icons.lock_outline, color: subTextColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: hintColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                      errorText: 'A jelszó megadása kötelező.'),
                  FormBuilderValidators.minLength(6,
                      errorText:
                          'A jelszónak legalább 6 karakter hosszúnak kell lennie.'),
                ]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFED2F5B),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  if (_formKey.currentState?.saveAndValidate() ?? false) {
                    debugPrint(_formKey.currentState?.value.toString());
                  }
                },
                child: const Text(
                  'Bejelentkezés',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterPrompt(
      Color textColor, Color subTextColor, bool isDarkMode) {
    // A kerettel ellátott doboz
    return Container(
      key: const ValueKey('registerPrompt'),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFED2F5B).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.nicepng.com/png/detail/304-3049649_badge-vintage-png-blank-vintage-logo-template-png.png',
              height: 100,
            ),
            const SizedBox(height: 24),
            Text(
              "Hozd létre a fiókod!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Csatlakozz hozzánk pár egyszerű lépésben.",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: subTextColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}