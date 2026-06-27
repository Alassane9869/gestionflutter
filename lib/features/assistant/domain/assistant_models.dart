// Assistant Domain Models

enum AssistantContext {
  dashboard,
  inventory,
  pos,
  finance,
  clients,
  suppliers,
  settings,
  reports,
  general
}

enum AssistantFlow {
  none,
  purchaseOrder,
  expense,
  client,
  product,
  quote
}

enum FlowStep {
  initial,
  supplier,
  items,
  amount,
  category,
  account,
  reason,
  name,
  phone,
  type,
  price,
  purchasePrice,
  quantity,
  barcode,
  unit,
  review,
  confirmation
}

class AssistantMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;
  final bool isError;
  final List<int>? attachmentBytes;
  final String? attachmentMimeType;
  final String? attachmentName;

  AssistantMessage({
    required this.text,
    this.isUser = false,
    DateTime? timestamp,
    this.isStreaming = false,
    this.isError = false,
    this.attachmentBytes,
    this.attachmentMimeType,
    this.attachmentName,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatThread {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<AssistantMessage> messages;

  ChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  ChatThread copyWith({
    String? id,
    String? title,
    DateTime? updatedAt,
    List<AssistantMessage>? messages,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => {
      'text': m.text,
      'isUser': m.isUser,
      'timestamp': m.timestamp.toIso8601String(),
      'isError': m.isError,
      'attachmentName': m.attachmentName,
      'attachmentMimeType': m.attachmentMimeType,
    }).toList(),
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final msgList = (json['messages'] as List<dynamic>?) ?? [];
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: msgList.map((item) {
        final map = item as Map<String, dynamic>;
        return AssistantMessage(
          text: map['text'] as String,
          isUser: map['isUser'] as bool? ?? false,
          timestamp: DateTime.parse(map['timestamp'] as String),
          isError: map['isError'] as bool? ?? false,
          attachmentName: map['attachmentName'] as String?,
          attachmentMimeType: map['attachmentMimeType'] as String?,
        );
      }).toList(),
    );
  }
}

class AssistantState {
  final List<AssistantMessage> messages;
  final bool isOpen;
  final bool isOnboardingActive;
  final int onboardingStep;
  final AssistantContext currentContext;
  final bool isTyping;
  final List<String> suggestedActions;
  
  // Multi-turn Flow State
  final AssistantFlow currentFlow;
  final FlowStep flowStep;
  final Map<String, dynamic> flowData;

  // History & Sidebar threads
  final List<ChatThread> threads;
  final String? currentThreadId;
  final bool isSidebarOpen;

  AssistantState({
    this.messages = const [],
    this.isOpen = false,
    this.isOnboardingActive = false,
    this.onboardingStep = 0,
    AssistantContext? currentContext,
    this.isTyping = false,
    this.suggestedActions = const [],
    this.currentFlow = AssistantFlow.none,
    this.flowStep = FlowStep.initial,
    this.flowData = const {},
    this.threads = const [],
    this.currentThreadId,
    this.isSidebarOpen = false,
  }) : currentContext = currentContext ?? AssistantContext.general;

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isOpen,
    bool? isOnboardingActive,
    int? onboardingStep,
    AssistantContext? currentContext,
    bool? isTyping,
    List<String>? suggestedActions,
    AssistantFlow? currentFlow,
    FlowStep? flowStep,
    Map<String, dynamic>? flowData,
    List<ChatThread>? threads,
    String? currentThreadId,
    bool? isSidebarOpen,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isOpen: isOpen ?? this.isOpen,
      isOnboardingActive: isOnboardingActive ?? this.isOnboardingActive,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      currentContext: currentContext ?? this.currentContext,
      isTyping: isTyping ?? this.isTyping,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      currentFlow: currentFlow ?? this.currentFlow,
      flowStep: flowStep ?? this.flowStep,
      flowData: flowData ?? this.flowData,
      threads: threads ?? this.threads,
      currentThreadId: currentThreadId ?? this.currentThreadId,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
    );
  }
}
