import 'package:flutter/material.dart';

/// Text that lays itself out for the script it is written in.
///
/// Urdu and Arabic are right-to-left: rendered with Flutter's default LTR
/// direction, a summary bullet reads correctly character by character but the
/// punctuation and any embedded English jump to the wrong end of the line.
class LangText extends StatelessWidget {
  const LangText(
    this.text, {
    super.key,
    this.language,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String? language;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static const Set<String> _rtlLanguages = {'ur', 'ar'};

  static final _arabicScript = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final _devanagari = RegExp(r'[\u0900-\u097F]');
  static final _latin = RegExp(r'[A-Za-z]');
  static final _urduOnly = RegExp(
    r'[\u067E\u0686\u0698\u06A9\u06AF\u0679\u0688\u0691'
    r'\u06BA\u06BB\u06BE\u06C1\u06C2\u06C3\u06CC\u06D2]',
  );
  static final _arabicOnly = RegExp(r'[\u0622\u0623\u0625\u0629\u0649\u0624\u0626]');

  static bool isRtl(String? language, [String? text]) {
    final code =
        (language ?? '').trim().toLowerCase().split(RegExp('[-_]')).first;
    if (_rtlLanguages.contains(code)) return true;
    if (code.isNotEmpty && code != 'auto') return false;
    // No usable tag (e.g. a hand-pasted transcript): fall back to the script.
    return text != null && _arabicScript.hasMatch(text);
  }

  /// Best-effort script detection so a line tagged `ur` that is actually
  /// English (Whisper hallucination) still goes through the right Opus pair.
  static String detectLanguage(String text, {String defaultLang = 'en'}) {
    final sample = text.trim();
    if (sample.isEmpty) return defaultLang;

    final arabic = _arabicScript.allMatches(sample).length;
    final devanagari = _devanagari.allMatches(sample).length;
    final latin = _latin.allMatches(sample).length;

    if (devanagari > 0 && devanagari >= arabic && devanagari >= latin) {
      return 'hi';
    }
    if (arabic > 0 && arabic >= latin) {
      final urdu = _urduOnly.hasMatch(sample);
      final arabicOnly = _arabicOnly.hasMatch(sample);
      if (urdu && !arabicOnly) return 'ur';
      if (arabicOnly && !urdu) return 'ar';
      if (defaultLang == 'ur' || defaultLang == 'ar') return defaultLang;
      return 'ur';
    }
    if (latin > 0) return 'en';
    return defaultLang;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = isRtl(language, text);
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
    );
  }
}
