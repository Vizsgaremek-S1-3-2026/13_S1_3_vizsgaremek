// lib/services/email_service.dart

import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../email_config.dart';
import 'email_template.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class EmailService {
  static DateTime? _lastSentTime;
  static const int _cooldownSeconds = 60;

  /// Returns the number of seconds remaining until the next email can be sent.
  /// Returns 0 if no cooldown is active.
  static int getRemainingCooldown() {
    if (_lastSentTime == null) return 0;
    final diff = DateTime.now().difference(_lastSentTime!).inSeconds;
    return max(0, _cooldownSeconds - diff);
  }

  /// Generates a random 6-character alphanumeric uppercase code
  static String generateVerificationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Omitted I, O, 0, 1 for clarity
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Sends the verification code to the target email address
  static Future<bool> sendVerificationCode(String recipientEmail, String code, {String? firstName, Uint8List? logoBytes}) async {
    // Check cooldown first
    final remaining = getRemainingCooldown();
    if (remaining > 0) {
      debugPrint('Email küldés várakoztatva: $remaining mp maradt.');
      return false;
    }

    // Basic credentials validation
    if (EmailConfig.senderEmail.isEmpty || EmailConfig.appPassword.isEmpty) {
      debugPrint('Hiba: Hiányzó e-mail konfiguráció (SENDER_EMAIL vagy APP_PASSWORD).');
      return false;
    }

    final smtpServer = gmail(EmailConfig.senderEmail, EmailConfig.appPassword);
    final String displayName = firstName ?? 'Felhasználó';

    final message = Message()
      ..from = Address(EmailConfig.senderEmail, 'cQuizy')
      ..recipients.add(recipientEmail)
      ..subject = EmailTemplate.subject
      ..text = EmailTemplate.getTextBody(code, displayName)
      ..html = EmailTemplate.getHtmlBody(code, displayName);

    if (logoBytes != null) {
      try {
        final attachment = StreamAttachment(
          Stream.value(logoBytes),
          'image/png',
          fileName: 'logo.png',
        )
          ..cid = 'logo@cquizy.app'
          ..location = Location.inline;
        attachment.additionalHeaders.addAll({'X-Attachment-Id': 'logo@cquizy.app'});
        message.attachments.add(attachment);
      } catch (e) {
        debugPrint('Hiba a logó csatolásakor: $e');
      }
    }

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Email elküldve: ${sendReport.toString()}');
      _lastSentTime = DateTime.now(); // Update cooldown start time
      return true;
    } on MailerException catch (e) {
      debugPrint('Email küldési hiba: $e');
      for (var p in e.problems) {
        debugPrint('Probléma: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('Váratlan hiba az email küldésekor: $e');
      return false;
    }
  }
}
