import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

import 'package:danaya_plus/features/assistant/application/assistant_service.dart';
import 'package:danaya_plus/features/assistant/application/voice_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class VirtualAssistantWidget extends ConsumerStatefulWidget {
  const VirtualAssistantWidget({super.key});

  @override
  ConsumerState<VirtualAssistantWidget> createState() =>
      _VirtualAssistantWidgetState();
}

class _VirtualAssistantWidgetState extends ConsumerState<VirtualAssistantWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;
  double? _customWidth;
  double? _customHeight;
  double _dragX = 0.0;
  double _dragY = 0.0;

  // ── Mini-bulle flottante pour appel vocal actif ──
  bool _isCallMinimized = false;
  double _bubbleX = 24.0;
  double _bubbleY = 100.0;
  Timer? _callTimer;

  // Scroll optimization: memoize state to avoid scrolling on every wave animation/rebuild
  bool _lastIsOpen = false;
  int _lastMessageCount = 0;
  String _lastMessageText = '';

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  List<int>? _attachedFileBytes;
  String? _attachedFileName;
  String? _attachedFileMimeType;

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && mounted) {
          setState(() {
            _attachedFileBytes = file.bytes;
            _attachedFileName = file.name;
            final extension = file.extension?.toLowerCase();
            if (extension == 'pdf') {
              _attachedFileMimeType = 'application/pdf';
            } else if (extension == 'png') {
              _attachedFileMimeType = 'image/png';
            } else if (extension == 'jpg' || extension == 'jpeg') {
              _attachedFileMimeType = 'image/jpeg';
            } else {
              _attachedFileMimeType = 'application/octet-stream';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la sélection du fichier : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _clearAttachment() {
    if (mounted) {
      setState(() {
        _attachedFileBytes = null;
        _attachedFileName = null;
        _attachedFileMimeType = null;
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedFileBytes == null) return;

    final messageText = text.isNotEmpty
        ? text
        : (_attachedFileMimeType == 'application/pdf'
              ? "Analyse ce fichier PDF"
              : "Analyse cette image");

    ref
        .read(assistantProvider.notifier)
        .sendMessage(
          messageText,
          attachmentBytes: _attachedFileBytes,
          attachmentMimeType: _attachedFileMimeType,
          attachmentName: _attachedFileName,
        );

    _textController.clear();
    _clearAttachment();
  }

  Widget _buildAttachmentPreview(ThemeData theme, bool isDark) {
    if (_attachedFileBytes == null) return const SizedBox.shrink();

    final isPdf = _attachedFileMimeType == 'application/pdf';

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14161E).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF1F2230)
                    : const Color(0xFFF0F1F4),
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D28) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2D38)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isPdf
                        ? FluentIcons.document_pdf_20_regular
                        : FluentIcons.image_20_regular,
                    color: isPdf ? Colors.redAccent : theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _attachedFileName ?? "Fichier sélectionné",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1D26),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    FluentIcons.dismiss_16_regular,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    size: 16,
                  ),
                  onPressed: _clearAttachment,
                  tooltip: "Supprimer le fichier",
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 150.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  bool _showScrollToBottom = false;

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
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset < _scrollController.position.maxScrollExtent - 200;
    if (show != _showScrollToBottom && mounted) {
      setState(() {
        _showScrollToBottom = show;
      });
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _controller.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Couper automatiquement l'appel vocal si le volet est fermé/détruit
    ref.read(voiceServiceProvider.notifier).endCall();
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

    // Auto-reset minimized state when call ends
    if (!voiceState.isCallActive && _isCallMinimized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isCallMinimized = false);
      });
    }

    // Manage call timer ticks
    if (voiceState.isCallActive) {
      if (_callTimer == null) {
        _startCallTimer();
      }
    } else {
      if (_callTimer != null) {
        _stopCallTimer();
      }
    }

    final lastMessageText = state.messages.isNotEmpty ? state.messages.last.text : '';
    final hasOpened = state.isOpen && !_lastIsOpen;
    final messagesChanged = state.messages.length != _lastMessageCount || lastMessageText != _lastMessageText;

    _lastIsOpen = state.isOpen;
    _lastMessageCount = state.messages.length;
    _lastMessageText = lastMessageText;

    if (state.isOpen) {
      _controller.forward();
      if (hasOpened || messagesChanged) {
        _scrollToBottom();
      }
    } else {
      _controller.reverse();
    }
    final sidebarWidth = (state.isSidebarOpen && !voiceState.isCallActive) ? 220.0 : 0.0;
    final defaultWidth = (_isExpanded ? 750.0 : 420.0) + sidebarWidth;
    final defaultHeight = _isExpanded ? 680.0 : 560.0;

    final panelWidth = _customWidth ?? defaultWidth;
    final panelHeight = _customHeight ?? defaultHeight;

    return Stack(
      children: [
        // ═══ MINI-BULLE FLOTTANTE (appel actif + minimisé) ═══
        if (voiceState.isCallActive && _isCallMinimized)
          Positioned(
            right: _bubbleX,
            bottom: _bubbleY,
            child: GestureDetector(
              onPanUpdate: (details) {
                if (mounted) {
                  setState(() {
                    _bubbleX -= details.delta.dx;
                    _bubbleY -= details.delta.dy;
                  });
                }
              },
              onTap: () {
                debugPrint('[VirtualAssistantWidget] Floating bubble clicked. Restoring call panel.');
                if (mounted) {
                  setState(() {
                    _isCallMinimized = false;
                  });
                }
                if (!state.isOpen) {
                  ref.read(assistantProvider.notifier).toggleOpen();
                }
              },
              child: _buildFloatingBubble(voiceState, theme, isDark),
            ),
          ),
        // AI PANEL
        Positioned(
          bottom: 100 + _dragY,
          right: 24 + _dragX,
          child: ScaleTransition(
            scale: _animation,
            child: FadeTransition(
              opacity: _animation,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: panelWidth,
                    height: panelHeight,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1117) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A2D38).withValues(alpha: 0.6)
                            : const Color(0xFFE2E5EC).withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.45 : 0.12,
                          ),
                          blurRadius: 48,
                          spreadRadius: -8,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 20,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          if (state.isSidebarOpen && !voiceState.isCallActive)
                            _buildSidebar(context, state, theme, isDark),
                          Expanded(
                            child: Column(
                              children: [
                                // ─── HEADER ───
                                _buildHeader(
                                  context,
                                  state,
                                  voiceState,
                                  theme,
                                  isDark,
                                ),

                                // ─── CONTENU PRINCIPAL ───
                                if (voiceState.isCallActive)
                                  Expanded(
                                    child: _buildVoiceCallScreen(
                                      context,
                                      voiceState,
                                    ),
                                  )
                                else ...[
                                  // AI PROVIDER BAR
                                  if (ref.watch(shopSettingsProvider).value != null)
                                    _buildProviderBar(theme, isDark),

                                  // CHAT CONTENT
                                  Expanded(
                                    child: _buildChatArea(state, theme, isDark),
                                  ),

                                  // ATTACHMENT PREVIEW BAR
                                  _buildAttachmentPreview(theme, isDark),

                                  // INPUT BAR
                                  _buildInputBar(voiceState, theme, isDark),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // RESIZE HANDLES
                  _buildResizeHandles(panelWidth, panelHeight, theme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(
    BuildContext context,
    AssistantState state,
    VoiceState voiceState,
    ThemeData theme,
    bool isDark,
  ) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (mounted) {
          setState(() {
            _dragX -= details.delta.dx;
            _dragY -= details.delta.dy;
          });
        }
      },
      onDoubleTap: () {
        if (mounted) {
          setState(() {
            _dragX = 0.0;
            _dragY = 0.0;
            _customWidth = null;
            _customHeight = null;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161E).withValues(alpha: 0.6)
            : const Color(0xFFF8F9FB).withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF2A2D38).withValues(alpha: 0.4)
                : const Color(0xFFE8EBF0).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!voiceState.isCallActive) ...[
            _headerIconButton(
              icon: FluentIcons.navigation_20_regular,
              tooltip: state.isSidebarOpen ? "Masquer l'historique" : "Afficher l'historique",
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              onTap: () {
                ref.read(assistantProvider.notifier).toggleSidebar();
              },
            ),
            const SizedBox(width: 8),
          ],
          // Logo + Status
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    FluentIcons.bot_24_regular,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: voiceState.isCallActive
                          ? Colors.greenAccent
                          : const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF14161E)
                            : const Color(0xFFF8F9FB),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "DANAYA Copilot",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1A1D26),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (voiceState.isCallActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF06B6D4,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF06B6D4,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF06B6D4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "EN DIRECT",
                              style: TextStyle(
                                color: Color(0xFF06B6D4),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getSubtitle(voiceState),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Minimize to bubble (only when call is active)
          if (voiceState.isCallActive)
            _headerIconButton(
              icon: FluentIcons.subtract_20_regular,
              tooltip: "Minimiser l'appel",
              color: const Color(0xFF06B6D4),
              onTap: () {
                debugPrint('[VirtualAssistantWidget] Minimize button clicked.');
                if (mounted) {
                  setState(() {
                    _isCallMinimized = true;
                  });
                }
                ref.read(assistantProvider.notifier).toggleOpen();
              },
            ),
          const SizedBox(width: 2),
          // Action buttons: New Discussion
          _headerIconButton(
            icon: FluentIcons.compose_20_regular,
            tooltip: "Nouvelle discussion",
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
            onTap: () => ref.read(assistantProvider.notifier).createNewThread(),
          ),
          const SizedBox(width: 2),
          _headerIconButton(
            icon: voiceState.isCallActive
                ? FluentIcons.call_end_20_filled
                : FluentIcons.call_20_regular,
            tooltip: voiceState.isCallActive ? "Raccrocher" : "Appeler Danaya",
            color: voiceState.isCallActive
                ? Colors.redAccent
                : theme.colorScheme.primary,
            onTap: () {
              if (voiceState.isCallActive) {
                ref.read(voiceServiceProvider.notifier).endCall();
              } else {
                ref.read(voiceServiceProvider.notifier).startCall();
              }
            },
          ),
          const SizedBox(width: 2),
          _headerIconButton(
            icon: _isExpanded
                ? FluentIcons.contract_down_left_20_regular
                : FluentIcons.expand_up_right_20_regular,
            tooltip: _isExpanded ? "Réduire" : "Agrandir",
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            onTap: () {
              if (mounted) {
                setState(() {
                  _isExpanded = !_isExpanded;
                  _customWidth = null;
                  _customHeight = null;
                });
              }
              _scrollToBottom();
            },
          ),
          const SizedBox(width: 2),
          _headerIconButton(
            icon: FluentIcons.dismiss_20_regular,
            tooltip: "Fermer",
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            onTap: () {
              debugPrint('[VirtualAssistantWidget] Close button clicked.');
              ref.read(assistantProvider.notifier).toggleOpen();
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  String _getSubtitle(VoiceState voiceState) {
    if (voiceState.isCallActive) {
      // Trouver le nom du modèle sélectionné
      final model = voiceState.availableLiveModels.firstWhere(
        (m) => m['id'] == voiceState.selectedLiveModel,
        orElse: () => {'name': voiceState.selectedLiveModel},
      );
      return "Appel direct • ${model['name']}";
    }
    final settings = ref.watch(shopSettingsProvider).value;
    if (settings?.useCloudAi == true) {
      return settings?.cloudAiProvider == 'gemini'
          ? 'Danaya 3.1 VIP ☁️'
          : 'Danaya 3.0 Standard 🧠';
    }
    return "Système hors-ligne 🛡️";
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI PROVIDER BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProviderBar(ThemeData theme, bool isDark) {
    final settings = ref.watch(shopSettingsProvider).value!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF12141B).withValues(alpha: 0.5)
            : const Color(0xFFFAFBFC).withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF1F2230).withValues(alpha: 0.4)
                : const Color(0xFFF0F1F4).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProviderPill(
              label: "Local",
              icon: FluentIcons.desktop_20_regular,
              isActive: !settings.useCloudAi,
              color: const Color(0xFF14B8A6),
              isDark: isDark,
              onTap: () => _updateAiProvider(false, 'local'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ProviderPill(
              label: " VIP AI",
              icon: FluentIcons.sparkle_20_regular,
              isActive:
                  settings.useCloudAi && settings.cloudAiProvider == 'gemini',
              color: const Color(0xFF6366F1),
              isDark: isDark,
              showKey: settings.geminiApiKey.isEmpty,
              onTap: () => _updateAiProvider(true, 'gemini'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ProviderPill(
              label: "Standard",
              icon: FluentIcons.brain_circuit_20_regular,
              isActive:
                  settings.useCloudAi && settings.cloudAiProvider == 'deepseek',
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              showKey: settings.deepSeekApiKey.isEmpty,
              onTap: () => _updateAiProvider(true, 'deepseek'),
            ),
          ),
        ],
      ),
    );
  }

  void _updateAiProvider(bool useCloud, String provider) {
    final s = ref.read(shopSettingsProvider).value;
    if (s == null) return;
    final updated = s.copyWith(useCloudAi: useCloud, cloudAiProvider: provider);
    ref.read(shopSettingsProvider.notifier).save(updated);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT AREA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChatArea(AssistantState state, ThemeData theme, bool isDark) {
    if (state.messages.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(theme, isDark),
            const SizedBox(height: 20),
            _buildPromptStarters(theme, isDark),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: state.messages.length + (state.isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.messages.length) {
              return const _TypingIndicator();
            }
            return _ChatBubble(msg: state.messages[index], isExpanded: _isExpanded);
          },
        ),
        if (_showScrollToBottom)
          Positioned(
            bottom: 16,
            right: 16,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      FluentIcons.chevron_down_16_filled,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      size: 16,
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 150.ms)
            .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          ),
      ],
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AssistantState state,
    ThemeData theme,
    bool isDark,
  ) {
    final bg = isDark ? const Color(0xFF17181C) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF2A2D38) : const Color(0xFFE5E7EB);
    
    // Grouper les threads par période
    final now = DateTime.now();
    final todayThreads = <ChatThread>[];
    final weekThreads = <ChatThread>[];
    final olderThreads = <ChatThread>[];

    for (final t in state.threads) {
      final diff = now.difference(t.updatedAt);
      if (diff.inDays == 0 && t.updatedAt.day == now.day) {
        todayThreads.add(t);
      } else if (diff.inDays < 7) {
        weekThreads.add(t);
      } else {
        olderThreads.add(t);
      }
    }

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        children: [
          // Bouton Nouvelle Discussion
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              onTap: () {
                ref.read(assistantProvider.notifier).createNewThread();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? const Color(0xFF1E2026) : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.add_20_regular,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Nouvelle discussion",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Liste des discussions
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (todayThreads.isNotEmpty) ...[
                  _buildSidebarHeader("Aujourd'hui", isDark),
                  ...todayThreads.map((t) => _buildSidebarItem(t, state.currentThreadId, isDark)),
                ],
                if (weekThreads.isNotEmpty) ...[
                  _buildSidebarHeader("7 derniers jours", isDark),
                  ...weekThreads.map((t) => _buildSidebarItem(t, state.currentThreadId, isDark)),
                ],
                if (olderThreads.isNotEmpty) ...[
                  _buildSidebarHeader("Plus anciens", isDark),
                  ...olderThreads.map((t) => _buildSidebarItem(t, state.currentThreadId, isDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 14, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(ChatThread thread, String? activeId, bool isDark) {
    final isActive = thread.id == activeId;
    final itemBg = isActive
        ? (isDark ? const Color(0xFF2E313E) : const Color(0xFFE5E7EB))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: InkWell(
        onTap: () {
          ref.read(assistantProvider.notifier).switchThread(thread.id);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.chat_20_regular,
                size: 14,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                // Bouton renommer
                GestureDetector(
                  onTap: () {
                    _showRenameDialog(thread);
                  },
                  child: Icon(
                    FluentIcons.edit_16_regular,
                    size: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 6),
                // Bouton supprimer
                GestureDetector(
                  onTap: () {
                    ref.read(assistantProvider.notifier).deleteThread(thread.id);
                  },
                  child: Icon(
                    FluentIcons.delete_16_regular,
                    size: 12,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(ChatThread thread) {
    final controller = TextEditingController(text: thread.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Renommer la discussion"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Valider"),
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                await ref.read(assistantProvider.notifier).renameThread(thread.id, newTitle);
              }
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FluentIcons.sparkle_24_filled,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Bienvenue sur DANAYA Copilot",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Votre assistant commercial IA de confiance. Analyse de stocks, suivi des dettes, bilans financiers et automatisation de tâches — disponible 100% local et hors-ligne.",
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              letterSpacing: -0.1,
              color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(
                icon: FluentIcons.shield_16_regular,
                label: "Données privées",
                isDark: isDark,
              ),
              _buildFeatureBadge(
                icon: FluentIcons.desktop_16_regular,
                label: "Mode Offline",
                isDark: isDark,
              ),
              _buildFeatureBadge(
                icon: FluentIcons.sparkle_16_regular,
                label: "VIP IA 3.1",
                isDark: isDark,
                isHighlight: true,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required bool isDark,
    bool isHighlight = false,
    ThemeData? theme,
  }) {
    final Color textColor = isHighlight
        ? Colors.white
        : (isDark ? const Color(0xFFE5E5EA) : const Color(0xFF48484A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlight && theme != null
            ? theme.colorScheme.primary.withValues(alpha: 0.9)
            : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? Colors.transparent : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA)),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isHighlight ? Colors.white : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF48484A)),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptStarters(ThemeData theme, bool isDark) {
    final starters = [
      {
        'title': 'Ruptures de stock',
        'desc': 'Produits bientôt en rupture',
        'icon': FluentIcons.warning_20_regular,
        'color': const Color(0xFFEF4444),
        'prompt':
            'Fais-moi un rapport sur mes produits bientôt en rupture de stock et dis-moi quoi acheter.',
      },
      {
        'title': 'Analyse rentabilité',
        'desc': 'Produits les plus rentables',
        'icon': FluentIcons.money_20_regular,
        'color': const Color(0xFF22C55E),
        'prompt':
            'Fais-moi une analyse détaillée de ma rentabilité et de mes produits les plus rentables.',
      },
      {
        'title': 'Clients débiteurs',
        'desc': 'Crédits en cours et montants',
        'icon': FluentIcons.people_20_regular,
        'color': const Color(0xFFF59E0B),
        'prompt':
            'Quels sont les clients qui me doivent de l\'argent et pour quel montant ?',
      },
      {
        'title': 'Bilan trésorerie',
        'desc': 'Ventes, dépenses, bénéfice net',
        'icon': FluentIcons.calculator_20_regular,
        'color': const Color(0xFF3B82F6),
        'prompt':
            'Donne-moi le bilan financier de ma boutique pour aujourd\'hui et cette semaine.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "Suggestions",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _isExpanded ? 2 : 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 68,
          ),
          itemCount: starters.length,
          itemBuilder: (context, index) {
            final item = starters[index];
            return _PromptCard(
              item: item,
              isDark: isDark,
              onTap: () => ref
                  .read(assistantProvider.notifier)
                  .sendMessage(item['prompt'] as String),
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INPUT BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputBar(VoiceState voiceState, ThemeData theme, bool isDark) {
    final isRecording = voiceState.isListening;
    final isTranscribing = voiceState.statusText == "Transcription...";
    final hasText = _textController.text.trim().isNotEmpty;

    // Détermination de l'action principale du bouton de droite
    final IconData actionIcon;
    final Color buttonColor;
    final String actionTooltip;
    final VoidCallback actionCallback;

    if (isRecording) {
      actionIcon = FluentIcons.checkmark_20_filled;
      buttonColor = Colors.green;
      actionTooltip = "Terminer et envoyer";
      actionCallback = () => ref.read(voiceServiceProvider.notifier).stopListening();
    } else if (hasText) {
      actionIcon = FluentIcons.send_20_filled;
      buttonColor = theme.colorScheme.primary;
      actionTooltip = "Envoyer";
      actionCallback = () => _handleSend();
    } else {
      actionIcon = FluentIcons.mic_20_regular;
      buttonColor = theme.colorScheme.primary;
      actionTooltip = "Dicter vocalement";
      actionCallback = () => ref.read(voiceServiceProvider.notifier).toggleListening();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161E).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF1F2230).withValues(alpha: 0.4)
                : const Color(0xFFF0F1F4).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isRecording
                    ? (isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.03))
                    : (isTranscribing
                        ? (isDark ? Colors.amber.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.03))
                        : (isDark ? const Color(0xFF1A1D28) : const Color(0xFFF3F4F6))),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRecording
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : (isTranscribing
                          ? Colors.amber.withValues(alpha: 0.3)
                          : (isDark
                                ? const Color(0xFF2A2D38)
                                : const Color(0xFFE5E7EB))),
                ),
              ),
              child: Row(
                children: [
                  if (isRecording) ...[
                    // Discard button on the left
                    IconButton(
                      icon: const Icon(
                        FluentIcons.delete_20_regular,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      onPressed: () => ref
                          .read(voiceServiceProvider.notifier)
                          .cancelListening(),
                      tooltip: "Annuler l'enregistrement",
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .fade(duration: 500.ms, begin: 0.2, end: 1.0),
                        const SizedBox(width: 6),
                        Text(
                          "${(voiceState.dictationDuration ~/ 60).toString().padLeft(2, '0')}:${(voiceState.dictationDuration % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Live responsive wave bars
                    Expanded(
                      child: Center(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final soundWaves = ref.watch(soundWavesProvider);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                20,
                                (index) {
                                  final double value = soundWaves.length > index
                                      ? soundWaves[index]
                                      : 0.08;
                                  final double height = (value * 28.0).clamp(4.0, 28.0);
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    width: 2.5,
                                    height: height,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Colors.redAccent, Colors.orangeAccent],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ] else if (isTranscribing) ...[
                    const Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation(Colors.amber),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Transcription en cours...",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(
                        FluentIcons.attach_20_regular,
                        color: _attachedFileBytes != null
                            ? theme.colorScheme.primary
                            : (isDark
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF9CA3AF)),
                        size: 18,
                      ),
                      onPressed: _pickAttachment,
                      tooltip: "Joindre une image de produit ou PDF",
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF1A1D26),
                        ),
                        decoration: InputDecoration(
                          hintText: "Posez votre question...",
                          hintStyle: TextStyle(
                            color: isDark
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (val) => _handleSend(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isTranscribing) ...[
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<IconData>(actionIcon),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      buttonColor,
                      buttonColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    actionIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: actionCallback,
                  tooltip: actionTooltip,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VOICE CALL SCREEN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVoiceCallScreen(BuildContext context, VoiceState voiceState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Palette de couleurs selon l'état
    final List<Color> coreGradient = voiceState.isSpeaking
        ? [theme.colorScheme.primary, const Color(0xFFA855F7)]
        : voiceState.isListening
        ? [const Color(0xFF14B8A6), const Color(0xFF3B82F6)]
        : [const Color(0xFF6366F1), const Color(0xFFA855F7)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight = constraints.maxHeight;
        final bool isCompact = maxHeight < 450;

        return Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF0A0C14) : const Color(0xFFF5F7FA),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Status Header ──
              _buildCallStatusHeader(voiceState, theme, isDark, isCompact),

              // ── Model/Voice Selector ──
              if (!isCompact) ...[
                const SizedBox(height: 8),
                _buildModelSelector(voiceState, theme, isDark),
              ],

              // ── Visualizer + Orb ──
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: isCompact ? 140 : 180,
                    width: double.infinity,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final soundWaves = ref.watch(soundWavesProvider);
                        final double amplitude = soundWaves.isNotEmpty
                            ? (soundWaves.reduce((a, b) => a + b) / soundWaves.length)
                            : 0.0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: LiquidWaveVisualizer(
                                audioAmplitude: amplitude,
                                colors: coreGradient,
                              ),
                            ),
                            AiGlowingOrb(
                              isActive:
                                  voiceState.isSpeaking ||
                                  voiceState.isListening ||
                                  voiceState.statusText.contains("réfléchit") ||
                                  voiceState.statusText.contains("parle"),
                              isListening: voiceState.isListening,
                              isSpeaking: voiceState.isSpeaking,
                              amplitude: amplitude,
                              colors: coreGradient,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Transcription Box ──
              _buildTranscriptionBox(voiceState, isDark, isCompact),

              const SizedBox(height: 12),

              // ── Call Controls ──
              _buildCallControls(voiceState, theme, isDark),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallStatusHeader(
    VoiceState voiceState,
    ThemeData theme,
    bool isDark,
    bool isCompact,
  ) {
    final statusColor = voiceState.isSpeaking
        ? theme.colorScheme.primary
        : voiceState.isMuted
        ? Colors.redAccent
        : const Color(0xFF22C55E);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                voiceState.statusText.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          Text(
            "Danaya Copilot",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1D26),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelSelector(
    VoiceState voiceState,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161E).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.sparkle_16_regular,
            color: isDark ? const Color(0xFF06B6D4) : theme.colorScheme.primary,
            size: 14,
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: voiceState.selectedLiveModel,
                  dropdownColor: isDark
                      ? const Color(0xFF1C1D2C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1D26),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: Icon(
                    FluentIcons.chevron_down_12_regular,
                    color: isDark
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF),
                    size: 12,
                  ),
                  items: voiceState.availableLiveModels.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['id'],
                      child: Text(m['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (String? newModel) {
                    if (newModel != null) {
                      ref
                          .read(voiceServiceProvider.notifier)
                          .changeLiveModel(newModel);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 14,
                  color: isDark
                      ? const Color(0xFF2A2D38)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: voiceState.selectedLiveVoice,
                  dropdownColor: isDark
                      ? const Color(0xFF1C1D2C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1D26),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: Icon(
                    FluentIcons.chevron_down_12_regular,
                    color: isDark
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF),
                    size: 12,
                  ),
                  items: voiceState.availableLiveVoices.map((v) {
                    return DropdownMenuItem<String>(
                      value: v['id'],
                      child: Text(v['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (String? newVoice) {
                    if (newVoice != null) {
                      ref
                          .read(voiceServiceProvider.notifier)
                          .changeLiveVoice(newVoice);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionBox(
    VoiceState voiceState,
    bool isDark,
    bool isCompact,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: isCompact ? 60 : 85),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF14161E).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE5E7EB),
          ),
        ),
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              voiceState.isSpeaking
                  ? voiceState.lastAiResponse
                  : (voiceState.lastWords.isNotEmpty
                        ? voiceState.lastWords
                        : "Parlez, je vous écoute..."),
              key: ValueKey<String>(
                voiceState.isSpeaking
                    ? voiceState.lastAiResponse
                    : voiceState.lastWords,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF1A1D26),
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                fontStyle:
                    (voiceState.isSpeaking || voiceState.lastWords.isNotEmpty)
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallControls(
    VoiceState voiceState,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14161E).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute
          _CallControlButton(
            icon: voiceState.isMuted
                ? FluentIcons.mic_off_20_regular
                : FluentIcons.mic_20_regular,
            label: voiceState.isMuted ? "Muet" : "Micro",
            color: voiceState.isMuted
                ? Colors.redAccent
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            isActive: voiceState.isMuted,
            isDark: isDark,
            onTap: () => ref.read(voiceServiceProvider.notifier).toggleMute(),
          ),
          const SizedBox(width: 20),

          // Hang up
          GestureDetector(
            onTap: () => ref.read(voiceServiceProvider.notifier).endCall(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                FluentIcons.call_end_20_filled,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Keyboard (exit to chat)
          _CallControlButton(
            icon: FluentIcons.keyboard_20_regular,
            label: "Clavier",
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            isActive: false,
            isDark: isDark,
            onTap: () => ref.read(voiceServiceProvider.notifier).endCall(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOATING CALL BUBBLE (Mini-assistant)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFloatingBubble(
    VoiceState voiceState,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: 180,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF0F1117)]
              : [Colors.white, const Color(0xFFF0F2F5)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: voiceState.isSpeaking
              ? const Color(0xFF06B6D4).withValues(alpha: 0.6)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (voiceState.isSpeaking
                    ? const Color(0xFF06B6D4)
                    : theme.colorScheme.primary)
                .withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Row(
          children: [
            const SizedBox(width: 6),
            // Animated pulsing indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: voiceState.isSpeaking
                      ? [const Color(0xFF06B6D4), const Color(0xFF0891B2)]
                      : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (voiceState.isSpeaking
                            ? const Color(0xFF06B6D4)
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                voiceState.isSpeaking
                    ? FluentIcons.speaker_2_20_filled
                    : (voiceState.isMuted
                        ? FluentIcons.mic_off_20_filled
                        : FluentIcons.mic_20_filled),
                color: Colors.white,
                size: 18,
              ),
            ).animate(
              onPlay: (c) => c.repeat(reverse: true),
            ).scaleXY(
              begin: 1.0,
              end: voiceState.isSpeaking ? 1.12 : 1.05,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            ),

            const SizedBox(width: 8),
            // Call status text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voiceState.isSpeaking ? 'Danaya parle...' : 'En appel',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1D26),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    voiceState.callDuration,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Hang up button
            GestureDetector(
              onTap: () {
                ref.read(voiceServiceProvider.notifier).endCall();
                if (mounted) {
                  setState(() {
                    _isCallMinimized = false;
                  });
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FluentIcons.call_end_16_filled,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESIZE HANDLES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResizeHandles(
    double panelWidth,
    double panelHeight,
    ThemeData theme,
  ) {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // LEFT
          Positioned(
            left: -4,
            top: 24,
            bottom: 24,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  if (mounted) {
                    setState(() {
                      _customWidth = (panelWidth - details.delta.dx).clamp(
                        360.0,
                        1200.0,
                      );
                    });
                  }
                },
                onDoubleTap: () {
                  if (mounted) {
                    setState(() {
                      _customWidth = null;
                      _customHeight = null;
                    });
                  }
                },
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // TOP
          Positioned(
            left: 24,
            right: 24,
            top: -4,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (mounted) {
                    setState(() {
                      _customHeight = (panelHeight - details.delta.dy).clamp(
                        400.0,
                        850.0,
                      );
                    });
                  }
                },
                onDoubleTap: () {
                  if (mounted) {
                    setState(() {
                      _customWidth = null;
                      _customHeight = null;
                    });
                  }
                },
                child: Container(
                  height: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // TOP-LEFT CORNER
          Positioned(
            left: -4,
            top: -4,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  if (mounted) {
                    setState(() {
                      _customWidth = (panelWidth - details.delta.dx).clamp(
                        360.0,
                        1200.0,
                      );
                      _customHeight = (panelHeight - details.delta.dy).clamp(
                        400.0,
                        850.0,
                      );
                    });
                  }
                },
                onDoubleTap: () {
                  if (mounted) {
                    setState(() {
                      _customWidth = null;
                      _customHeight = null;
                    });
                  }
                },
                child: Container(
                  width: 16,
                  height: 16,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _ProviderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color color;
  final bool isDark;
  final bool showKey;
  final VoidCallback onTap;

  const _ProviderPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.color,
    required this.isDark,
    this.showKey = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: isDark ? 0.12 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? color
                  : (isDark
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? Colors.white : color)
                      : (isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showKey) ...[
              const SizedBox(width: 3),
              Icon(
                FluentIcons.key_16_regular,
                size: 9,
                color: Colors.amber.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2D38)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final VoidCallback onTap;

  const _PromptCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.item['color'] as Color;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, _isHovered ? -3.0 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : (isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.7) : const Color(0xFFF2F2F7).withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? iconColor.withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? iconColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isHovered ? iconColor : iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item['icon'] as IconData,
                  color: _isHovered ? Colors.white : iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item['desc'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_isHovered ? 3.0 : 0.0, 0.0, 0.0),
                child: Icon(
                  FluentIcons.chevron_right_12_regular,
                  size: 14,
                  color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT BUBBLE
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatBubble extends ConsumerWidget {
  final AssistantMessage msg;
  final bool isExpanded;

  const _ChatBubble({required this.msg, required this.isExpanded});

  Widget _buildBubbleAttachment(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    if (msg.attachmentName == null) return const SizedBox.shrink();

    final isPdf = msg.attachmentMimeType == 'application/pdf';
    final hasBytes = msg.attachmentBytes != null;
    final isImage = msg.attachmentMimeType?.startsWith('image/') ?? false;

    Widget attachmentWidget;

    if (isImage && hasBytes) {
      attachmentWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 180),
          width: double.infinity,
          child: Image.memory(
            Uint8List.fromList(msg.attachmentBytes!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFileBadge(theme, isDark, isPdf),
          ),
        ),
      );
    } else {
      attachmentWidget = _buildFileBadge(theme, isDark, isPdf);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: attachmentWidget,
    );
  }

  Widget _buildFileBadge(ThemeData theme, bool isDark, bool isPdf) {
    final textColor = msg.isUser
        ? Colors.white.withValues(alpha: 0.95)
        : (isDark
              ? Colors.white.withValues(alpha: 0.9)
              : const Color(0xFF374151));

    final badgeBg = msg.isUser
        ? Colors.white.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF1E2230) : const Color(0xFFF3F4F6));

    final badgeBorder = msg.isUser
        ? Border.all(color: Colors.white.withValues(alpha: 0.2))
        : Border.all(
            color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE5E7EB),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
        border: badgeBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdf
                ? FluentIcons.document_pdf_16_regular
                : FluentIcons.document_16_regular,
            color: msg.isUser
                ? Colors.white
                : (isPdf ? Colors.redAccent : theme.colorScheme.primary),
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg.attachmentName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantAvatar(ThemeData theme, bool isDark) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          FluentIcons.sparkle_16_filled,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme, bool isDark, WidgetRef ref) {
    final user = ref.read(authServiceProvider).value;
    final initial = user != null && user.username.isNotEmpty ? user.username[0].toUpperCase() : 'P';
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final styleSheet = MarkdownStyleSheet(
      p: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF1C1C1E),
        fontSize: 13.5,
        height: 1.6,
        letterSpacing: -0.1,
      ),
      strong: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
        fontWeight: FontWeight.bold,
      ),
      em: const TextStyle(fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: theme.colorScheme.primary, fontSize: 13.5),
      listBulletPadding: const EdgeInsets.only(right: 8, top: 5),
      h1: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
      h2: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
      h3: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
      ),
      blockquote: TextStyle(
        color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF48484A),
        fontSize: 12.5,
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      code: TextStyle(
        color: isDark ? const Color(0xFFE5E5EA) : const Color(0xFF24292F),
        backgroundColor: isDark
            ? const Color(0xFF1C1C1E)
            : Colors.black.withValues(alpha: 0.04),
        fontFamily: 'monospace',
        fontSize: 11.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF161822) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2E3E) : const Color(0xFFE5E7EB),
          width: 0.8,
        ),
      ),
      tableBorder: TableBorder.all(
        color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
        width: 0.8,
      ),
      tableBody: TextStyle(
        color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
        fontSize: 12.5,
      ),
      tableHead: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 12.5,
      ),
      tableCellsPadding: const EdgeInsets.all(10),
    );

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              _buildAssistantAvatar(theme, isDark),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: msg.isUser
                          ? LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: msg.isUser
                          ? null
                          : (isDark
                              ? const Color(0xFF1E2230)
                              : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                      ),
                      border: msg.isUser
                          ? null
                          : Border.all(
                              color: isDark
                                  ? const Color(0xFF2C2F3E)
                                  : const Color(0xFFE5E7EB),
                              width: 1.0,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (msg.isUser
                                  ? theme.colorScheme.primary
                                  : Colors.black).withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(maxWidth: isExpanded ? 600 : 280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBubbleAttachment(context, theme, isDark),
                        if (msg.isUser)
                          Text(
                            msg.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                          )
                        else if (msg.isStreaming && ref.watch(assistantProvider.select((s) => s.isOpen)))
                          _TypewriterMarkdown(
                            text: msg.text,
                            styleSheet: styleSheet,
                            onComplete: () {
                              ref
                                  .read(assistantProvider.notifier)
                                  .markMessageStreamingCompleted(msg.text);
                            },
                          )
                        else
                          MarkdownBody(
                            data: msg.text,
                            selectable: false,
                            styleSheet: styleSheet,
                          ),
                      ],
                    ),
                  ),
                  // Actions row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormatter.formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _BubbleAction(
                          icon: FluentIcons.copy_16_regular,
                          label: "Copier",
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: msg.text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Copié ! 📋"),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  width: 180,
                                  backgroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        if (msg.isError) ...[
                          const SizedBox(width: 6),
                          _BubbleAction(
                            icon: FluentIcons.arrow_clockwise_16_regular,
                            label: "Réessayer",
                            color: theme.colorScheme.primary,
                            onTap: () => ref
                                .read(assistantProvider.notifier)
                                .retryLastFailedMessage(),
                          ),
                        ],
                        if (!msg.isUser) ...[
                          const SizedBox(width: 6),
                          _BubbleAction(
                            icon: FluentIcons.print_16_regular,
                            label: "PDF",
                            onTap: () => _printMessage(context, msg, theme),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (msg.isUser) ...[
              const SizedBox(width: 8),
              _buildUserAvatar(theme, isDark, ref),
            ],
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 200.ms)
    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  void _printMessage(
    BuildContext context,
    AssistantMessage msg,
    ThemeData theme,
  ) async {
    try {
      await Printing.layoutPdf(
        name: "Rapport_DANAYA_Copilot",
        onLayout: (PdfPageFormat format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (pw.Context context) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DANAYA Copilot — Rapport",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        "Généré le ${DateFormatter.formatDate(DateTime.now())} à ${DateTime.now().hour}h${DateTime.now().minute.toString().padLeft(2, '0')}",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        msg.text,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
          return doc.save();
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur impression : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _BubbleAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _BubbleAction({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  State<_BubbleAction> createState() => _BubbleActionState();
}

class _BubbleActionState extends State<_BubbleAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final activeColor = widget.color ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? (isDark ? Colors.white12 : Colors.black12)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: _isHovered ? activeColor : defaultColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  color: _isHovered ? activeColor : defaultColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPING INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════

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
          color: isDark ? const Color(0xFF1A1D28) : const Color(0xFFF3F4F6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D38) : const Color(0xFFE8EBF0),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(delay: (index * 200).ms)
                .scale(duration: 600.ms)
                .moveY(
                  begin: 2,
                  end: -2,
                  duration: 600.ms,
                  curve: Curves.easeInOut,
                );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPEWRITER MARKDOWN
// ═══════════════════════════════════════════════════════════════════════════════

class _TypewriterMarkdown extends StatefulWidget {
  final String text;
  final MarkdownStyleSheet styleSheet;
  final VoidCallback onComplete;

  const _TypewriterMarkdown({
    required this.text,
    required this.styleSheet,
    required this.onComplete,
  });

  @override
  State<_TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<_TypewriterMarkdown> {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(_TypewriterMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _startTyping();
    }
  }

  void _startTyping() {
    _currentIndex = 0;
    _displayedText = '';

    // Step size and interval optimized to buffer/debounce text streaming and avoid flooding the main Win32 thread (80ms debounce rate)
    final step = (widget.text.length > 500)
        ? 16
        : ((widget.text.length > 200) ? 8 : 4);
    final interval = const Duration(milliseconds: 80);

    _timer = Timer.periodic(interval, (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _currentIndex = math.min(_currentIndex + step, widget.text.length);
            _displayedText = widget.text.substring(0, _currentIndex);
          });
        }
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex < widget.text.length) {
      return Text(
        _displayedText,
        style:
            widget.styleSheet.p ?? const TextStyle(fontSize: 13, height: 1.6),
      );
    }
    return MarkdownBody(
      data: widget.text,
      selectable: false,
      styleSheet: widget.styleSheet,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIQUID WAVE VISUALIZER
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidWaveVisualizer extends StatefulWidget {
  final double audioAmplitude;
  final List<Color> colors;

  const LiquidWaveVisualizer({
    super.key,
    required this.audioAmplitude,
    required this.colors,
  });

  @override
  State<LiquidWaveVisualizer> createState() => _LiquidWaveVisualizerState();
}

class _LiquidWaveVisualizerState extends State<LiquidWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _phaseController;

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _phaseController,
      builder: (context, child) {
        return CustomPaint(
          painter: LiquidWavePainter(
            phase: _phaseController.value * 2 * math.pi,
            amplitude: widget.audioAmplitude,
            colors: widget.colors,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class LiquidWavePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final List<Color> colors;

  LiquidWavePainter({
    required this.phase,
    required this.amplitude,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double halfHeight = size.height / 2;
    final double width = size.width;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final double wavePhase = phase * (1.0 + i * 0.15) + (i * math.pi / 2);
      final double waveFrequency = 0.012 + (i * 0.004);
      final double targetAmp =
          (amplitude > 0.05 ? amplitude : 0.06) * (size.height * 0.35);
      final double waveAmplitude = targetAmp * (1.0 - (i * 0.22));
      final Color waveColor = colors[i % colors.length].withValues(
        alpha: 0.65 - (i * 0.18),
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 - (i * 0.5)
        ..color = waveColor
        ..strokeCap = StrokeCap.round;

      path.moveTo(0, halfHeight);
      for (double x = 0; x <= width; x += 3) {
        final double damping = math.sin((x / width) * math.pi);
        final double y =
            halfHeight +
            math.sin(x * waveFrequency + wavePhase) * waveAmplitude * damping;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      if (i == 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..color = waveColor.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.amplitude != amplitude;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI GLOWING ORB
// ═══════════════════════════════════════════════════════════════════════════════

class AiGlowingOrb extends StatefulWidget {
  final bool isActive;
  final bool isListening;
  final bool isSpeaking;
  final double amplitude;
  final List<Color> colors;

  const AiGlowingOrb({
    super.key,
    required this.isActive,
    required this.isListening,
    required this.isSpeaking,
    required this.amplitude,
    required this.colors,
  });

  @override
  State<AiGlowingOrb> createState() => _AiGlowingOrbState();
}

class _AiGlowingOrbState extends State<AiGlowingOrb>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: const Icon(
          FluentIcons.bot_24_regular,
          color: Colors.white24,
          size: 28,
        ),
      );
    }

    final double voiceScale = 1.0 + (widget.amplitude * 0.12);

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        final double pulse = _pulseController.value;
        final double rotation = _rotationController.value * 2 * math.pi;

        return Transform.scale(
          scale: voiceScale * (0.96 + (pulse * 0.04)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dynamic Glowing Halo (Backpack)
              Container(
                width: 120 + (widget.amplitude * 15.0),
                height: 120 + (widget.amplitude * 15.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colors[0].withValues(alpha: 0.14 + (pulse * 0.04)),
                      blurRadius: 28 + (widget.amplitude * 12),
                      spreadRadius: 2 + (widget.amplitude * 4),
                    ),
                    BoxShadow(
                      color: widget.colors[1].withValues(alpha: 0.08 + (pulse * 0.03)),
                      blurRadius: 40 + (widget.amplitude * 15),
                      spreadRadius: 1 + (widget.amplitude * 3),
                    ),
                  ],
                ),
              ),
              // Halo 2 (Breathing Radial Gradient)
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.colors[0].withValues(alpha: 0.18 * pulse),
                      widget.colors[1].withValues(alpha: 0.04 * (1.0 - pulse)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Outer rotating neon ring
              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        widget.colors[0],
                        widget.colors[1],
                        widget.colors[0].withValues(alpha: 0.2),
                        widget.colors[1],
                        widget.colors[0],
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Inner rotating neon ring
              Transform.rotate(
                angle: -rotation * 1.5,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        widget.colors[1],
                        widget.colors[0],
                        widget.colors[1].withValues(alpha: 0.15),
                        widget.colors[0],
                        widget.colors[1],
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Glass sphere with premium reflection & shadow
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.09),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35 + (widget.amplitude * 0.15)),
                        width: 1.2 + (widget.amplitude * 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors[0].withValues(alpha: 0.2 + (widget.amplitude * 0.1)),
                          blurRadius: 12 + (widget.amplitude * 4),
                          spreadRadius: 0.5 + (widget.amplitude * 0.5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.isSpeaking
                            ? FluentIcons.speaker_2_24_regular
                            : widget.isListening
                            ? FluentIcons.mic_24_regular
                            : FluentIcons.sparkle_24_regular,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
