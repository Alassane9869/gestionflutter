import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

import 'package:danaya_plus/features/assistant/application/assistant_service.dart';
import 'package:danaya_plus/features/assistant/application/voice_service.dart';

class VirtualAssistantWidget extends ConsumerStatefulWidget {
  const VirtualAssistantWidget({super.key});

  @override
  ConsumerState<VirtualAssistantWidget> createState() => _VirtualAssistantWidgetState();
}

class _VirtualAssistantWidgetState extends ConsumerState<VirtualAssistantWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final voiceState = ref.watch(voiceServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isOpen) {
      _controller.forward();
      _scrollToBottom();
    } else {
      _controller.reverse();
    }

    return Stack(
      children: [
        // AI PANEL
        Positioned(
          bottom: 100,
          right: 24,
          child: ScaleTransition(
            scale: _animation,
            child: FadeTransition(
              opacity: _animation,
              child: Container(
                width: 350,
                height: 500,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161623).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 50,
                      spreadRadius: -10,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                    child: Column(
                      children: [
                        // HEADER
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary.withValues(alpha: 0.95), theme.colorScheme.primary.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(FluentIcons.bot_sparkle_24_filled, color: Colors.white, size: 22),
                              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.5)),
                              const SizedBox(width: 15),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Intelligence TITAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                                    Text("Système 100% Hors-Ligne", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.dismiss_24_regular, color: Colors.white),
                                tooltip: "Masquer dans l'en-tête",
                                onPressed: () => ref.read(assistantProvider.notifier).toggleOpen(),
                              ),
                            ],
                          ),
                        ),
                        // MESSAGES
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == state.messages.length) {
                                return const _TypingIndicator();
                              }
                              final msg = state.messages[index];
                              return _ChatBubble(msg: msg);
                            },
                          ),
                        ),
                        // SUGGESTED ACTIONS
                        if (state.suggestedActions.isNotEmpty)
                          SizedBox(
                            height: 45,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: state.suggestedActions.length,
                              itemBuilder: (context, index) {
                                final action = state.suggestedActions[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: ActionChip(
                                    label: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                                    onPressed: () => ref.read(assistantProvider.notifier).sendMessage(action),
                                  ),
                                );
                              },
                            ),
                          ),
                        // ONBOARDING PROGRESS
                        if (state.isOnboardingActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                Text("Étape ${state.onboardingStep}/5", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => ref.read(assistantProvider.notifier).nextOnboardingStep(),
                                  child: const Text("Suivant"),
                                ),
                              ],
                            ),
                          ),
                        // INPUT
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  decoration: const InputDecoration(
                                    hintText: "Posez votre question...",
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(fontSize: 14),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      ref.read(assistantProvider.notifier).sendMessage(val);
                                      _textController.clear();
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  voiceState.isListening ? FluentIcons.mic_sparkle_24_filled : FluentIcons.mic_24_regular,
                                  color: voiceState.isListening ? Colors.redAccent : theme.colorScheme.primary.withValues(alpha: 0.7),
                                ).animate(target: voiceState.isListening ? 1 : 0)
                                 .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 500.ms, curve: Curves.easeInOut)
                                 .then().shake(duration: 500.ms),
                                onPressed: () => ref.read(voiceServiceProvider.notifier).toggleListening(),
                                tooltip: "Navigation Vocale",
                              ),
                              IconButton(
                                icon: Icon(FluentIcons.send_24_filled, color: theme.colorScheme.primary),
                                onPressed: () {
                                  if (_textController.text.trim().isNotEmpty) {
                                    ref.read(assistantProvider.notifier).sendMessage(_textController.text);
                                    _textController.clear();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AssistantMessage msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: msg.isUser 
                  ? LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: msg.isUser 
                  ? null 
                  : (isDark ? const Color(0xFF2D2D3D) : const Color(0xFFF0F2F5)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                fontSize: 14,
                height: 1.4,
                fontWeight: msg.isUser ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(
              DateFormatter.formatTime(msg.timestamp),
              style: TextStyle(fontSize: 9, color: Colors.grey.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF3F4F6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fadeIn(delay: (index * 200).ms)
             .scale(duration: 600.ms)
             .moveY(begin: 2, end: -2, duration: 600.ms, curve: Curves.easeInOut);
          }),
        ),
      ),
    );
  }
}
