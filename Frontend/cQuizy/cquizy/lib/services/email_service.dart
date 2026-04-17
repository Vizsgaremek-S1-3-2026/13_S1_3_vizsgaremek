// lib/services/email_service.dart

import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../email_config.dart';
import 'email_template.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class EmailService {
  /// Generates a random 6-character alphanumeric uppercase code
  static String generateVerificationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Omitted I, O, 0, 1 for clarity
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Sends the verification code to the target email address
  static Future<bool> sendVerificationCode(String recipientEmail, String code, {Uint8List? logoBytes}) async {
    final smtpServer = gmail(EmailConfig.senderEmail, EmailConfig.appPassword);

    final message = Message()
      ..from = Address(EmailConfig.senderEmail, 'cQuizy')
      ..recipients.add(recipientEmail)
      ..subject = EmailTemplate.subject
      ..text = EmailTemplate.getTextBody(code)
      ..html = EmailTemplate.getHtmlBody(code);

    if (logoBytes != null) {
      final attachment = StreamAttachment(
        Stream.value(logoBytes),
        'image/png',
        fileName: 'logo.png',
      )
        ..cid = 'logo@cquizy.app'
        ..location = Location.inline;
      attachment.additionalHeaders.addAll({'X-Attachment-Id': 'logo@cquizy.app'});
      message.attachments.add(attachment);
    }

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Email elküldve: ${sendReport.toString()}');
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
