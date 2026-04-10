enum RuleTriggerType {
  stockLow,
  stockOut,
  saleCompleted,
  dailyClosing,
  customerDebtExceeded,
  suspiciousDiscount,
  saleLarge,
  timeScheduled
}

enum RuleActionType {
  notifyUser,
  sendEmail,
  sendSMS,
  blockCustomer,
  adjustPrice,
  generateReport,
  triggerMacro
}

class BusinessRule {
  final String id;
  final String name;
  final RuleTriggerType trigger;
  final RuleActionType action;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> actionPayload;
  final bool isActive;
  final DateTime? lastTriggered;

  BusinessRule({
    required this.id,
    required this.name,
    required this.trigger,
    required this.action,
    required this.conditions,
    required this.actionPayload,
    this.isActive = true,
    this.lastTriggered,
  });

  BusinessRule copyWith({
    String? id,
    String? name,
    RuleTriggerType? trigger,
    RuleActionType? action,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? actionPayload,
    bool? isActive,
    DateTime? lastTriggered,
  }) {
    return BusinessRule(
      id: id ?? this.id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      conditions: conditions ?? this.conditions,
      actionPayload: actionPayload ?? this.actionPayload,
      isActive: isActive ?? this.isActive,
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trigger': trigger.name,
    'action': action.name,
    'conditions': conditions,
    'actionPayload': actionPayload,
    'isActive': isActive,
    'lastTriggered': lastTriggered?.toIso8601String(),
  };

  factory BusinessRule.fromJson(Map<String, dynamic> json) => BusinessRule(
    id: json['id'],
    name: json['name'],
    trigger: RuleTriggerType.values.byName(json['trigger']),
    action: RuleActionType.values.byName(json['action']),
    conditions: json['conditions'],
    actionPayload: json['actionPayload'],
    isActive: json['isActive'] ?? true,
    lastTriggered: json['lastTriggered'] != null ? DateTime.parse(json['lastTriggered']) : null,
  );
}

class RuleEngine {
  final List<BusinessRule> _rules = [];

  void addRule(BusinessRule rule) {
    _rules.add(rule);
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  List<BusinessRule> getActiveRulesFor(RuleTriggerType trigger) {
    return _rules.where((r) => r.isActive && r.trigger == trigger).toList();
  }

  bool checkCondition(BusinessRule rule, Map<String, dynamic> data) {
    switch (rule.trigger) {
      case RuleTriggerType.stockLow:
        final currentQty = (data['quantity'] as num).toDouble();
        final threshold = (rule.conditions['threshold'] as num).toDouble();
        return currentQty <= threshold;
      
      case RuleTriggerType.suspiciousDiscount:
        final discountPercent = (data['discountPercent'] as num).toDouble();
        final maxAllowed = (rule.conditions['maxAllowed'] as num).toDouble();
        return discountPercent > maxAllowed;

      case RuleTriggerType.customerDebtExceeded:
        final currentDebt = (data['debt'] as num).toDouble();
        final limit = (rule.conditions['limit'] as num).toDouble();
        return currentDebt > limit;
      
      case RuleTriggerType.saleLarge:
        final amount = (data['amount'] as num).toDouble();
        final threshold = (rule.conditions['threshold'] as num).toDouble();
        return amount > threshold;

      default:
        return false;
    }
  }
}
