import 'package:flutter/material.dart';

import '../../services/ai_client.dart';

/// Live caption strip for video/meeting screens.
///
/// Shows two lines: what the other participant said (already translated into
/// *my* language) and what I said last. The language selector applies to both
/// my captions and the voice I hear.
class LiveCaptionOverlay extends StatelessWidget {
  const LiveCaptionOverlay({
    super.key,
    required this.myLang,
    required this.isBusy,
    this.onMyLangChanged,
    this.mySpeech = '',
    this.incomingSpeaker = '',
    this.incomingText = '',
    this.isSpeaking = false,
    this.phase = 'idle',
  });

  /// The language I chose: captions and spoken audio both arrive in it.
  final String myLang;
  final ValueChanged<String>? onMyLangChanged;

  /// My own recognized speech, in my language.
  final String mySpeech;

  /// Somebody else's words, already translated into [myLang].
  final String incomingSpeaker;
  final String incomingText;

  final bool isBusy;
  final bool isSpeaking;
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.72),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Live captions',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSpeaking ? 'speaking' : phase,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _LangDropdown(
              value: myLang,
              label: 'My language (hear & read in this)',
              onChanged: onMyLangChanged,
            ),
            const SizedBox(height: 10),

            // What the other side said, in my language — the important line.
            Text(
              incomingText.isEmpty
                  ? 'Waiting for someone to speak…'
                  : (incomingSpeaker.isEmpty
                      ? incomingText
                      : '$incomingSpeaker: $incomingText'),
              style: TextStyle(
                color: incomingText.isEmpty ? Colors.white38 : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // What I said, for confidence that the mic is being heard.
            Text(
              mySpeech.isEmpty ? 'You: …' : 'You: $mySpeech',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LangDropdown extends StatelessWidget {
  const _LangDropdown({
    required this.value,
    required this.label,
    this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final codes = LangCodes.nameToCode.values.toList();
    final safe = codes.contains(value) ? value : 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: safe,
            isDense: true,
            dropdownColor: Colors.grey.shade900,
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: LangCodes.nameToCode.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(e.key),
                  ),
                )
                .toList(),
            onChanged: onChanged == null
                ? null
                : (v) {
                    if (v != null) onChanged!(v);
                  },
          ),
        ),
      ],
    );
  }
}
