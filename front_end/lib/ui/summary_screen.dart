import 'package:flutter/material.dart';

import '../services/ai_client.dart';
import 'chatbot_screen.dart';

class SummaryScreen extends StatefulWidget {
  final String? title;
  final String? duration;
  final List<String>? participants;
  final String? transcript;

  const SummaryScreen({
    super.key,
    this.title,
    this.duration,
    this.participants,
    this.transcript,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _ai = AiClient();
  late final TextEditingController _transcriptController;

  bool _loading = false;
  bool _hasRun = false;
  String? _error;
  String _overview = '';
  List<String> _keyPoints = const [];
  List<String> _actionItems = const [];

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(text: widget.transcript ?? '');
    if ((_transcriptController.text).trim().length >= 20) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSummarize());
    }
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _runSummarize() async {
    final text = _transcriptController.text.trim();
    if (text.length < 20) {
      setState(() {
        _error = 'Transcript must be at least 20 characters.';
        _overview = '';
        _keyPoints = const [];
        _actionItems = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _ai.summarize(transcript: text);
      if (!mounted) return;
      setState(() {
        _overview = result.summary;
        _keyPoints = result.keyPoints;
        _actionItems = result.actionItems;
        _loading = false;
        _hasRun = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _overview = '';
        _keyPoints = const [];
        _actionItems = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summarize failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transcriptText = _transcriptController.text;

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF39A935), Color(0xFF2E8B2B)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
                Text(
                  "AI Meeting Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.smart_toy, color: Colors.white)
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFE8F8E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.psychology,
                                  size: 16, color: Color(0xFF39A935)),
                              SizedBox(width: 6),
                              Text("Backend /summarize",
                                  style: TextStyle(
                                      color: Color(0xFF39A935),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          widget.title ?? "Meeting",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            _chip(Icons.access_time, widget.duration ?? ""),
                            SizedBox(width: 8),
                            _chip(Icons.group,
                                "${widget.participants?.length ?? 0} Participants"),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          widget.participants?.join(", ") ?? "",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // Transcript input (paste when no live meeting transcript)
                  _section(
                    icon: Icons.description,
                    title: "Transcript",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _transcriptController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText:
                                "Paste meeting transcript (min 20 characters)…",
                            filled: true,
                            fillColor: Color(0xFFF1F3F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Color(0xFF39A935),
                            ),
                            onPressed: _loading ? null : _runSummarize,
                            icon: _loading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.auto_awesome),
                            label: Text(_loading
                                ? "Generating…"
                                : "Generate AI Summary"),
                          ),
                        ),
                        if (_error != null) ...[
                          SizedBox(height: 8),
                          Text(_error!,
                              style: TextStyle(color: Colors.red.shade700)),
                        ],
                      ],
                    ),
                  ),

                  if (_overview.isNotEmpty)
                    _section(
                      icon: Icons.text_snippet,
                      title: "Overview",
                      child: Text(_overview),
                    ),

                  // A model can return text we cannot place into any section.
                  // Say so instead of showing a silently blank screen.
                  if (!_loading &&
                      _error == null &&
                      _overview.isEmpty &&
                      _keyPoints.isEmpty &&
                      _actionItems.isEmpty &&
                      _hasRun)
                    _section(
                      icon: Icons.info_outline,
                      title: "No summary yet",
                      child: Text(
                        "The model did not return a usable summary. Tap "
                        "\"Generate AI Summary\" to try again — a longer "
                        "transcript usually gives a better result.",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),

                  if (_keyPoints.isNotEmpty)
                    _section(
                      icon: Icons.star_border,
                      title: "Key Points",
                      child: Column(
                        children: _keyPoints
                            .map((e) => Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Color(0xFF39A935)),
                                      SizedBox(width: 6),
                                      Expanded(child: Text(e)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                  if (_actionItems.isNotEmpty)
                    _section(
                      icon: Icons.assignment_turned_in,
                      title: "Action Items",
                      child: Column(
                        children: _actionItems
                            .map((e) => Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF7FBF6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          color: Color(0xFF39A935)),
                                      SizedBox(width: 8),
                                      Expanded(child: Text(e)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                  if (transcriptText.trim().isNotEmpty && _overview.isNotEmpty)
                    _section(
                      icon: Icons.notes,
                      title: "Source Transcript",
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F3F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(transcriptText),
                      ),
                    ),

                  if (transcriptText.trim().length >= 20) ...[
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatbotScreen(
                                  transcript: transcriptText,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.chat_bubble_outline),
                          label: Text('Ask chatbot about this transcript'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Color(0xFF39A935),
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF39A935)),
              SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 10),
          child
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }
}
