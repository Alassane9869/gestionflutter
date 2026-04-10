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
  product
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

  AssistantMessage({
    required this.text,
    this.isUser = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
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
    );
  }
}
