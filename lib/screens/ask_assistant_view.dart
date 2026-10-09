import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';

class AskAssistantView extends StatefulWidget {
  const AskAssistantView({super.key});

  @override
  State<AskAssistantView> createState() => _AskAssistantViewState();
}

class _AskAssistantViewState extends State<AskAssistantView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _messages = <_Message>[];
  bool _isLoading = false;

  // Mock memory retrieval based on diary entries
  String _getMockResponse(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('meeting') || lower.contains('call')) {
      return 'You have a meeting at 5:00 PM at the swimming pool';
    }
    if (lower.contains('workout') || lower.contains('run') || lower.contains('exercise')) {
      return 'Your morning run was 5km at 7:00 AM. Great pace!';
    }
    if (lower.contains('daily') || lower.contains('recap') || lower.contains('today')) {
      return 'Today you spent time on app development and had dinner with family.';
    }
    return 'I recall something about that... perhaps check your diary entries for more details.';
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message.user(text));
      _controller.clear();
    });

    // Simulate assistant response with a small delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add(_Message.assistant(_getMockResponse(text)));
        });
      }
    });

    // Clear loading state
    if (_isLoading) {
      setState(() => _isLoading = false);
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = const Color(0xFFF5F1E9);
    final textColor = const Color(0xFF4A453F);
    final accentColor = const Color(0xFF899386);
    final actionColor = const Color(0xFF6F819A);
    final userBg = bgColor;
    final assistantBg = actionColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, isDark),
      body: Column(
        children: [
          // Q&A list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _MessageBubble(
                message: _messages[index],
                userBg: userBg,
                assistantBg: assistantBg,
                textColor: textColor,
              ),
            ),
          ),
          // Input bar
          _buildInputBar(context, isDark, textColor),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: const Color(0xFFF5F1E9),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Ask Assistant',
        style: GoogleFonts.lato(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4A453F),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark, Color textColor) {
    const actionColor = Color(0xFF6F819A);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      child: Row(
        children: [
          // Mic button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.mic,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF4A453F),
            ),
          ),
          const SizedBox(width: 12),
          // Question input
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ask about your day...',
                hintStyle: GoogleFonts.lato(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
              cursorColor: const Color(0xFF899386),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              decoration: BoxDecoration(
                color: actionColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.send,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final _MessageType type;
  final DateTime timestamp;

  _Message._(this.text, this.type) : timestamp = DateTime.now();

  factory _Message.user(String text) => _Message._(text, _MessageType.user);

  factory _Message.assistant(String text) => _Message._(text, _MessageType.assistant);
}

enum _MessageType { user, assistant }

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final Color userBg;
  final Color assistantBg;
  final Color textColor;

  const _MessageBubble({
    required this.message,
    required this.userBg,
    required this.assistantBg,
    required this.textColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == _MessageType.user;
    final bg = isUser ? userBg : assistantBg;
    final text = isUser ? textColor : Colors.white;
    final font = isUser ? GoogleFonts.lato : GoogleFonts.ebGaramond;

    // Position bubble based on sender
    final align = isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.text,
          style: font(
            color: text,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}