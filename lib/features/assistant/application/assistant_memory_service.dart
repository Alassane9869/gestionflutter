import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

class MemoryFact {
  final String id;
  final String fact;
  final DateTime createdAt;

  MemoryFact({
    required this.id,
    required this.fact,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fact': fact,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MemoryFact.fromJson(Map<String, dynamic> json) => MemoryFact(
    id: json['id'] as String,
    fact: json['fact'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

final assistantMemoryProvider = NotifierProvider<AssistantMemoryNotifier, List<MemoryFact>>(AssistantMemoryNotifier.new);

class AssistantMemoryNotifier extends Notifier<List<MemoryFact>> {
  static const _legacyStorageKey = 'danaya_copilot_memory_facts';
  final _uuid = const Uuid();

  String get _storageKey {
    final user = ref.read(authServiceProvider).value;
    final userId = user?.id ?? 'guest';
    return 'danaya_copilot_memory_facts_$userId';
  }

  @override
  List<MemoryFact> build() {
    // Watch the auth state so we rebuild and load correct memories if the user changes
    ref.watch(authServiceProvider);
    Future.microtask(() => loadMemories());
    return [];
  }

  Future<void> loadMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey;
      var jsonStr = prefs.getString(key);

      // Migrate from legacy global memory to user-specific memory if needed
      if (jsonStr == null) {
        final legacyJson = prefs.getString(_legacyStorageKey);
        if (legacyJson != null) {
          jsonStr = legacyJson;
          await prefs.setString(key, legacyJson);
          // Clean up legacy key so it only migrates once
          await prefs.remove(_legacyStorageKey);
        }
      }

      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        state = decoded.map((item) => MemoryFact.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        state = [];
      }

      // Toujours s'assurer que le fait fondateur de DANAYA+ est présent dans la mémoire
      final founderFactExists = state.any((m) => m.fact.toLowerCase().contains("alassane diarra"));
      if (!founderFactExists) {
        state = [
          ...state,
          MemoryFact(
            id: 'danaya_founder_fact',
            fact: "Le créateur et fondateur de DANAYA+ est Alassane Diarra.",
            createdAt: DateTime(2024, 1, 1),
          )
        ];
      }
    } catch (e) {
      state = [];
    }
  }

  Future<void> saveMemory(String fact) async {
    // Nettoyer et valider le fait pour s'assurer qu'il respecte les politiques simples
    final cleanedFact = fact.trim();
    if (cleanedFact.isEmpty) return;

    // Protection politique de sécurité étendue
    final lower = cleanedFact.toLowerCase();
    // 1. Mots-clés interdits (données d'identification & bancaires)
    if (lower.contains('mot de passe') || lower.contains('password') ||
        lower.contains('carte de crédit') || lower.contains('credit card') ||
        lower.contains('clé api') || lower.contains('api key') ||
        lower.contains('token') || lower.contains('secret') ||
        lower.contains('cvv') || lower.contains('pin')) {
      throw Exception("Politique de sécurité : Il est interdit de stocker des informations d'identification ou bancaires dans la mémoire du Copilot.");
    }
    // 2. Numéros de carte bancaire (13-19 chiffres consécutifs)
    if (RegExp(r'\b\d{13,19}\b').hasMatch(cleanedFact)) {
      throw Exception("Politique de sécurité : Numéro de carte bancaire détecté. Stockage refusé.");
    }
    // 3. Adresses email explicites (x@x.x)
    if (RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').hasMatch(cleanedFact) &&
        (lower.contains('passe') || lower.contains('identifiant') || lower.contains('login'))) {
      throw Exception("Politique de sécurité : Information de connexion (email + identifiant) refusée.");
    }

    final newFact = MemoryFact(
      id: _uuid.v4(),
      fact: cleanedFact,
      createdAt: DateTime.now(),
    );

    state = [...state, newFact];
    await _persist();
  }

  Future<void> updateMemory(String id, String newFact) async {
    final cleanedFact = newFact.trim();
    if (cleanedFact.isEmpty) return;

    final lower = cleanedFact.toLowerCase();
    // 1. Mots-clés interdits
    if (lower.contains('mot de passe') || lower.contains('password') ||
        lower.contains('carte de crédit') || lower.contains('credit card') ||
        lower.contains('clé api') || lower.contains('api key') ||
        lower.contains('token') || lower.contains('secret') ||
        lower.contains('cvv') || lower.contains('pin')) {
      throw Exception("Politique de sécurité : Il est interdit de stocker des informations d'identification ou bancaires dans la mémoire du Copilot.");
    }
    // 2. Numéros de carte bancaire
    if (RegExp(r'\b\d{13,19}\b').hasMatch(cleanedFact)) {
      throw Exception("Politique de sécurité : Numéro de carte bancaire détecté. Stockage refusé.");
    }

    state = state.map((m) {
      if (m.id == id) {
        return MemoryFact(id: m.id, fact: cleanedFact, createdAt: m.createdAt);
      }
      return m;
    }).toList();
    await _persist();
  }

  Future<void> deleteMemory(String id) async {
    state = state.where((m) => m.id != id).toList();
    await _persist();
  }

  Future<void> clearMemories() async {
    state = [
      MemoryFact(
        id: 'danaya_founder_fact',
        fact: "Le créateur et fondateur de DANAYA+ est Alassane Diarra.",
        createdAt: DateTime(2024, 1, 1),
      )
    ];
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(state.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      // Ignorer ou logger
    }
  }

  /// Retourne une chaîne de texte formatée représentant les souvenirs
  /// pour injection directe dans le prompt système
  String getFormattedMemoryPrompt() {
    if (state.isEmpty) return "";

    final buffer = StringBuffer();
    buffer.writeln("=== MÉMOIRE PERSISTANTE (PRÉFÉRENCES & CONSIGNES À RESPECTER) ===");
    buffer.writeln("Tu as mémorisé les informations et règles suivantes dictées par l'utilisateur par le passé.");
    buffer.writeln("Tu dois ABSOLUMENT les respecter dans tes réponses et actions :");
    for (var i = 0; i < state.length; i++) {
      buffer.writeln("${i + 1}. [ID: ${state[i].id}] ${state[i].fact}");
    }
    buffer.writeln("Note : Ne révèle pas les identifiants ID à moins que l'utilisateur te demande de gérer ou supprimer un souvenir précis.");
    return buffer.toString();
  }
}
