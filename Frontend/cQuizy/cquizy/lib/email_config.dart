// lib/email_config.dart

class EmailConfig {
  /// The Gmail address used to send verification codes.
  /// Set this during build: --dart-define=SENDER_EMAIL=your_email@gmail.com
  static const String senderEmail = String.fromEnvironment(
    'SENDER_EMAIL',
    defaultValue: 'mkaroly210@gmail.com', // Keep existing as fallback for now
  );
  
  /// The 16-character Gmail App Password.
  /// Set this during build: --dart-define=APP_PASSWORD=your_app_password
  static const String appPassword = String.fromEnvironment(
    'APP_PASSWORD',
    defaultValue: 'giwk ntkm nsli jzgb', // Keep existing as fallback for now
  );
}
