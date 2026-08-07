import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_client.dart';

class TranslateScreen extends StatefulWidget {
  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _ai = AiClient();
  final _inputController = TextEditingController();

  final List<String> languages = LangCodes.displayNames;

  String translatedText = '';
  String? errorText;
  bool loading = false;

  String sourceLang = 'English';
  String targetLang = 'Urdu';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> handleTranslate() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) return;

    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final result = await _ai.translate(
        text: inputText,
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );
      if (!mounted) return;
      setState(() {
        translatedText = result.translatedText;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = e.toString();
        translatedText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    }
  }

  void swapLanguages() {
    setState(() {
      final temp = sourceLang;
      sourceLang = targetLang;
      targetLang = temp;
      if (translatedText.isNotEmpty) {
        final previousInput = _inputController.text;
        _inputController.text = translatedText;
        translatedText = previousInput;
      }
    });
  }

  void openLanguagePicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          padding: EdgeInsets.all(20),
          height: 350,
          child: Column(
            children: [
              Text("Select Language",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (_, i) {
                    return ListTile(
                      title: Text(languages[i]),
                      onTap: () {
                        setState(() {
                          if (type == 'source') {
                            sourceLang = languages[i];
                          } else {
                            targetLang = languages[i];
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FA),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF39A935), Color(0xFF2D8E2A)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
                Column(
                  children: [
                    Text("AI Translator",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text("Connected to ConvoBridge backend",
                        style:
                            TextStyle(color: Color(0xFFE8FFE6), fontSize: 12)),
                  ],
                ),
                Icon(Icons.smart_toy, color: Colors.white)
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _langCard("FROM", sourceLang, () {
                            openLanguagePicker('source');
                          }),
                        ),
                        GestureDetector(
                          onTap: swapLanguages,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF39A935),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.swap_horiz, color: Colors.white),
                          ),
                        ),
                        Expanded(
                          child: _langCard("TO", targetLang, () {
                            openLanguagePicker('target');
                          }),
                        ),
                      ],
                    ),
                  ),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Enter Text",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        TextField(
                          controller: _inputController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: "Type text to translate...",
                            border: InputBorder.none,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _circleBtn(Icons.close, Colors.red, onTap: () {
                              setState(() {
                                _inputController.clear();
                                translatedText = '';
                                errorText = null;
                              });
                            }),
                          ],
                        )
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: loading ? null : handleTranslate,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Color(0xFF39A935),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: loading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.translate, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Translate",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(errorText!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  SizedBox(height: 20),
                  if (translatedText.isNotEmpty)
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Translation Result",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE8FFE6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text("Opus-MT",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF39A935),
                                        fontWeight: FontWeight.w600)),
                              )
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(translatedText, style: TextStyle(fontSize: 16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _circleBtn(Icons.copy, Color(0xFF39A935),
                                  onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: translatedText));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied')),
                                );
                              }),
                            ],
                          )
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                  Text("Powered by ConvoBridge FastAPI /translate",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langCard(String label, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(text,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: child,
    );
  }

  Widget _circleBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: 10),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(0xFFF1F3F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
