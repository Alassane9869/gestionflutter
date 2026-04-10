import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rule_engine.dart';

final ruleManagerProvider = NotifierProvider<RuleManager, List<BusinessRule>>(RuleManager.new);

class RuleManager extends Notifier<List<BusinessRule>> {
  static const _storageKey = 'titan_business_rules';

  @override
  List<BusinessRule> build() {
    _loadRules();
    return [];
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonStr);
        state = jsonList.map((j) => BusinessRule.fromJson(j)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> saveRules(List<BusinessRule> rules) async {
    state = rules;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(rules.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  void addRule(BusinessRule rule) {
    final newState = [...state, rule];
    saveRules(newState);
  }

  void removeRule(String id) {
    final newState = state.where((r) => r.id != id).toList();
    saveRules(newState);
  }

  void toggleRule(String id) {
    final newState = state.map((r) {
      if (r.id == id) {
        return r.copyWith(isActive: !r.isActive);
      }
      return r;
    }).toList();
    saveRules(newState);
  }
}
