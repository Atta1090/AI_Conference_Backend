import 'package:flutter/material.dart';

import '../services/ai_client.dart';
import 'widgets/lang_text.dart';

class ChatbotScreen extends StatefulWidget {
  final String? transcript;
  final String? meetingId;

  /// Language to answer in — the language this user picked in the meeting.
  final String? language;

  /// Per-line transcript with spoken languages, so the backend can normalise a
  /// mixed-language meeting before answering.
  final List<TranscriptEntry>? utterances;

  const ChatbotScreen({
    super.key,
    this.transcript,
    this.meetingId,
    this.language,
    this.utterances,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ai = AiClient();
  final controller = TextEditingController();
  late final TextEditingController _transcriptController;

  /// Greeting shown in the language the meeting was held in, so an Urdu user
  /// is not met by an English wall of text.
  static const Map<String, String> _greetings = {
    'en': "Hello — I am your ConvoBridge Meeting Assistant. Ask questions "
        "about the transcript below.",
    'ur': "السلام علیکم — میں آپ کا کنوو برج میٹنگ اسسٹنٹ ہوں۔ نیچے دی گئی "
        "ٹرانسکرپٹ کے بارے میں سوال پوچھیں۔",
    'ar': "مرحبا — أنا مساعد الاجتماعات في ConvoBridge. اسأل عن النص أدناه.",
    'hi': "नमस्ते — मैं आपका ConvoBridge मीटिंग असिस्टेंट हूँ। नीचे दिए गए "
        "ट्रांसक्रिप्ट के बारे में प्रश्न पूछें।",
  };

  static const Map<String, String> _failureText = {
    'en': "Sorry — chatbot request failed.",
    'ur': "معاف کیجیے — چیٹ بوٹ کی درخواست ناکام ہو گئی۔",
    'ar': "عذرًا — فشل طلب المحادثة.",
    'hi': "क्षमा करें — चैटबॉट अनुरोध विफल रहा।",
  };

  static const Map<String, String> _hintText = {
    'en': "Ask about the meeting…",
    'ur': "میٹنگ کے بارے میں پوچھیں…",
    'ar': "اسأل عن الاجتماع…",
    'hi': "बैठक के बारे में पूछें…",
  };

  late final List<Map<String, String>> messages;

  bool loading = false;
  bool _showTranscript = false;

  static const _sampleTranscript = '''
Ahmed: We need to finish the project report by Friday.
Sara: I will handle the design section.
John: I can review the budget numbers tonight.
Ahmed: Great. Let's meet again on Monday at 10 AM.
''';

  late String _replyLang;

  String get _language => _replyLang;

  String _localized(Map<String, String> table) =>
      table[_language] ?? table['en']!;

  @override
  void initState() {
    super.initState();
    final initial = (widget.transcript != null && widget.transcript!.trim().isNotEmpty)
        ? widget.transcript!.trim()
        : _sampleTranscript.trim();
    _transcriptController = TextEditingController(text: initial);
    _replyLang = widget.language ?? 'en';
    messages = [
      {
        "id": "1",
        "text": _localized(_greetings),
        "sender": "bot",
        "lang": _language,
      }
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final userText = controller.text.trim();
    if (userText.isEmpty || loading) return;

    setState(() {
      messages.add({
        "id": DateTime.now().toString(),
        "text": userText,
        "sender": "user",
        "lang": _language,
      });
      controller.clear();
      loading = true;
    });

    try {
      final result = await _ai.askChatbot(
        question: userText,
        transcript: _transcriptController.text.trim(),
        meetingId: widget.meetingId,
        language: _language,
        utterances: widget.utterances,
      );
      if (!mounted) return;
      setState(() {
        messages.add({
          "id": DateTime.now().toString(),
          "text": result.answer,
          "sender": "bot",
          "lang": result.language,
        });
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add({
          "id": DateTime.now().toString(),
          "text": "${_localized(_failureText)}\n$e",
          "sender": "bot",
          "lang": _language,
        });
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        title: Text("AI Meeting Assistant"),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: "Answer language",
            initialValue: _replyLang,
            onSelected: (v) => setState(() => _replyLang = v),
            icon: const Icon(Icons.language),
            itemBuilder: (ctx) => LangCodes.nameToCode.entries
                .map(
                  (e) => PopupMenuItem<String>(
                    value: e.value,
                    child: Text(e.key),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: "Transcript context",
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            icon: Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showTranscript)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Meeting transcript (context)",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: _transcriptController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Paste meeting transcript…",
                      filled: true,
                      fillColor: Color(0xFFF1F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(15),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var msg = messages[index];
                bool isUser = msg["sender"] == "user";

                return Row(
                  mainAxisAlignment:
                      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isUser)
                      Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.smart_toy,
                            color: Color(0xFF39A935), size: 28),
                      ),
                    Container(
                      constraints: BoxConstraints(maxWidth: 280),
                      margin: EdgeInsets.only(bottom: 14),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Color(0xFF39A935) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: isUser
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2,
                                )
                              ],
                      ),
                      child: LangText(
                        msg["text"]!,
                        language: msg["lang"] ?? _language,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (loading)
            Padding(
              padding: EdgeInsets.only(left: 15, bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text("AI thinking..."),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !loading,
                    onSubmitted: (_) => sendMessage(),
                    textDirection: LangText.isRtl(_language)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: _localized(_hintText),
                      filled: true,
                      fillColor: Color(0xFFF1F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: loading ? null : sendMessage,
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Color(0xFF39A935),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
