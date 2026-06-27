import 'dart:math';

enum ToneSeverity { info, warning, success, urgent }

class AssistantTone {
  static final _random = Random();

  // --- Salutations & Encouragements ---
  static const _morningGreetings = [
    "Bonjour Boss ! La caisse est prête, on fait péter les scores aujourd'hui ? 🚀",
    "Excellent début de journée ! Prêt à gérer ta boutique de main de maître ? 📈",
    "Salut ! Tous les systèmes sont au vert. Quelle est notre première action ? 🟢",
  ];

  static const _fatigueWarnings = [
    "💚 Je vois que tu travailles depuis un moment. Prends un café, je garde un oeil sur le stock.",
    "🛡️ Plus de 6 heures de session... Le repos est ton arme secrète ! Prends 15min.",
    "☕ Tu es une machine, mais même les machines ont besoin de recharger. Fais une pause, Chef.",
  ];

  static const _salesRecords = [
    "🔥 EXCEPTIONNEL ! Nouveau record de vente. Tu es inarrêtable !",
    "🏆 MAGNIFIQUE ! Les chiffres explosent aujourd'hui. On sabre le champagne ?",
    "💰 BOOM ! Record d'encaissement battu. Le travail acharné paie, bravo Boss !",
  ];

  static const _deadStockAlerts = [
    "📦 J'ai repéré des produits qui dorment un peu trop longtemps en rayon. Tu veux qu'on fasse une petite promo pour les écouler ?",
    "🕸️ Attention au capital immobilisé : certains articles n'ont pas bougé depuis 30 jours. Tu devrais peut-être les mettre en avant.",
    "💡 Suggestion Titan : Certains de tes produits prennent la poussière. Une remise groupée pourrait libérer de l'espace et de la trésorerie.",
  ];

  static const _churnAlerts = [
    "👥 Alerte Fidélité : Certains de tes bons clients ne sont pas venus depuis plus d'un mois. Un petit SMS de ta part pourrait faire la différence.",
    "🚨 Rétention : J'ai identifié des clients 'fantômes' qui achetaient souvent avant. Tu veux la liste pour les relancer ?",
    "🤝 Ne les laisse pas partir chez la concurrence ! Plusieurs clients VIP n'ont rien acheté récemment.",
  ];

  static const _genericAcknowledgments = [
    "C'est noté. Autre chose ?",
    "Parfait, je m'en occupe.",
    "Mission accomplie. ✅",
    "Entendu !",
  ];

  // --- Générateurs ---

  static String greeting({String? userName}) {
    final base = _randomElement(_morningGreetings);
    if (userName != null && userName != "patron") {
      if (base.contains("Boss")) {
        return base.replaceAll("Boss", userName);
      } else if (base.contains("Salut !")) {
        return base.replaceAll("Salut !", "Salut $userName !");
      } else {
        return "Bonjour $userName ! $base";
      }
    }
    return base;
  }
  static String fatigueWarning() => _randomElement(_fatigueWarnings);
  static String salesRecord() => _randomElement(_salesRecords);
  static String deadStock() => _randomElement(_deadStockAlerts);
  static String clientChurn() => _randomElement(_churnAlerts);
  static String ack() => _randomElement(_genericAcknowledgments);

  static String custom(List<String> variations) => _randomElement(variations);

  static String _randomElement(List<String> list) {
    if (list.isEmpty) return "";
    return list[_random.nextInt(list.length)];
  }
}
