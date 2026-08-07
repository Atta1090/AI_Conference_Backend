import 'package:flutter/material.dart';

import '../services/ai_client.dart';

class ChatbotScreen extends StatefulWidget {
  final String? transcript;
  final String? meetingId;

  const ChatbotScreen({
    super.key,
    this.transcript,
    this.meetingId,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ai = AiClient();
  final controller = TextEditingController();
  late final TextEditingController _transcriptController;

  List<Map<String, String>> messages = [
    {
      "id": "1",
      "text":
          "Hello — I am your ConvoBridge Meeting Assistant. Ask questions about the transcript below.",
      "sender": "bot"
    }
  ];

  bool loading = false;
  bool _showTranscript = false;

  static const _sampleTranscript = '''
Ahmed: We need to finish the project report by Friday.
Sara: I will handle the design section.
John: I can review the budget numbers tonight.
Ahmed: Great. Let's meet again on Monday at 10 AM.
''';

  @override
  void initState() {
    super.initState();
    final initial = (widget.transcript != null && widget.transcript!.trim().isNotEmpty)
        ? widget.transcript!.trim()
        : _sampleTranscript.trim();
    _transcriptController = TextEditingController(text: initial);
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
      });
      controller.clear();
      loading = true;
    });

    try {
      final result = await _ai.askChatbot(
        question: userText,
        transcript: _transcriptController.text.trim(),
        meetingId: widget.meetingId,
      );
      if (!mounted) return;
      setState(() {
        messages.add({
          "id": DateTime.now().toString(),
          "text": result.answer,
          "sender": "bot",
        });
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add({
          "id": DateTime.now().toString(),
          "text": "Sorry — chatbot request failed.\n$e",
          "sender": "bot",
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
                      child: Text(
                        msg["text"]!,
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
                    decoration: InputDecoration(
                      hintText: "Ask about the meeting…",
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
