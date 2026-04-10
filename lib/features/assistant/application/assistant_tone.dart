import 'dart:math';

enum ToneSeverity { info, warning, success, urgent }

class AssistantTone {
  static final _random = Random();

  // --- Salutations & Encouragements ---
  static const _morningGreetings = [
    "Bonjour Boss ! La caisse est prête, on fait péter les scores aujourd'hui ? 🚀",
    "Excellent début de journée ! Prêt à gérer la boutique de main de maître ? 📈",
    "Bonjour ! Tous les systèmes sont au vert. Quelle est notre première action ? 🟢",
  ];

  static const _fatigueWarnings = [
    "💚 Je vois que vous travaillez depuis un moment. Prenez un café, je garde un oeil sur le stock.",
    "🛡️ Plus de 6 heures de session... Le repos est l'arme secrète des grands leaders ! Prenez 15min.",
    "☕ Vous êtes une machine, mais même les machines ont besoin de recharger. Faites une pause, Chef.",
  ];

  static const _salesRecords = [
    "🔥 EXCEPTIONNEL ! Nouveau record de vente. Vous êtes inarrêtable !",
    "🏆 MAGNIFIQUE ! Les chiffres explosent aujourd'hui. On sabre le champagne ?",
    "💰 BOOM ! Record d'encaissement battu. Le travail acharné paie, bravo Boss !",
  ];

  static const _deadStockAlerts = [
    "📦 J'ai repéré des produits qui dorment un peu trop longtemps en rayon. Voulez-vous qu'on fasse une petite promo pour les écouler ?",
    "🕸️ Attention au capital immobilisé : certains articles n'ont pas bougé depuis 30 jours. On devrait peut-être les mettre en avant.",
    "💡 Suggestion Titan : Certains de vos produits prennent la poussière. Une remise groupée pourrait libérer de l'espace et de la trésorerie.",
  ];

  static const _churnAlerts = [
    "👥 Alerte Fidélité : Certains de vos bons clients ne sont pas venus depuis plus d'un mois. Un petit SMS pourrait faire la différence.",
    "🚨 Rétention : J'ai identifié des clients 'fantômes' qui achetaient souvent avant. Voulez-vous la liste pour les relancer ?",
    "🤝 Ne les laissez pas partir chez la concurrence ! Plusieurs clients VIP n'ont rien acheté récemment.",
  ];

  static const _genericAcknowledgments = [
    "C'est noté. Autre chose ?",
    "Parfait, je m'en occupe.",
    "Mission accomplie. ✅",
    "Entendu !",
  ];

  // --- Générateurs ---

  static String greeting() => _randomElement(_morningGreetings);
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
