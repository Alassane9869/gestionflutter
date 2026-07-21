class EmailTemplates {
  /// Liste de tous les templates disponibles avec leurs métadonnées.
  static const List<Map<String, String>> catalog = [
    // CLASSIC
    {'id': 'classic', 'category': 'Professionnel', 'name': 'Classic Pro', 'desc': 'Sobre et professionnel, header bleu navy'},
    {'id': 'classic_minimal', 'category': 'Professionnel', 'name': 'Classic Minimal', 'desc': 'Épuré avec bordure subtile, très corporate'},
    {'id': 'classic_corporate', 'category': 'Professionnel', 'name': 'Classic Corporate', 'desc': 'Palette charbon, header dégradé sobre'},
    // MODERN
    {'id': 'modern', 'category': 'Moderne', 'name': 'Modern Startup', 'desc': 'Badge pill arrondi, design tech aéré'},
    {'id': 'modern_dark', 'category': 'Moderne', 'name': 'Modern Dark', 'desc': 'Mode sombre élégant, accents cyan'},
    {'id': 'modern_gradient', 'category': 'Moderne', 'name': 'Modern Gradient', 'desc': 'Header gradient bleu-indigo vibrant'},
    // ELEGANT
    {'id': 'elegant', 'category': 'Élégant', 'name': 'Élégant Premium', 'desc': 'Bordure dorée, police serif luxueuse'},
    {'id': 'elegant_rose', 'category': 'Élégant', 'name': 'Élégant Rosé', 'desc': 'Tons rose poudré et or, ultra féminin'},
    {'id': 'elegant_midnight', 'category': 'Élégant', 'name': 'Élégant Midnight', 'desc': 'Fond bleu nuit profond, accents argent'},
    // ALERT
    {'id': 'alert', 'category': 'Alerte', 'name': 'Alerte Standard', 'desc': 'Bande rouge latérale, icône ⚠️'},
    {'id': 'alert_orange', 'category': 'Alerte', 'name': 'Alerte Avertissement', 'desc': 'Tonalités orange, alerte modérée'},
    {'id': 'alert_critical', 'category': 'Alerte', 'name': 'Alerte Critique', 'desc': 'Header rouge vif plein, urgence maximale'},
    // MARKETING
    {'id': 'marketing', 'category': 'Marketing', 'name': 'Marketing Promo', 'desc': 'Gradient violet, bouton CTA central'},
    {'id': 'marketing_warm', 'category': 'Marketing', 'name': 'Marketing Chaleureux', 'desc': 'Tons corail-orange, ambiance soleil'},
    {'id': 'marketing_neon', 'category': 'Marketing', 'name': 'Marketing Néon', 'desc': 'Fond sombre avec accents vert néon'},
  ];

  /// Génère le rendu HTML final en injectant le contenu dans le template choisi.
  static String buildHtml(String templateId, {
    required String subject,
    required String body,
    required String shopName,
  }) {
    final year = DateTime.now().year;

    // Construit le corps avec des paragraphes si ce n'est pas déjà formaté
    String formattedBody = body;
    if (!body.contains('<p>') && !body.contains('<br>')) {
      formattedBody = '<p>${body.replaceAll('\n', '<br>')}</p>';
    }

    String rawHtml = '';
    switch (templateId.toLowerCase()) {
      case 'modern':
        rawHtml = _modernTemplate(subject, formattedBody, shopName, year);
        break;
      case 'modern_dark':
        rawHtml = _modernDarkTemplate(subject, formattedBody, shopName, year);
        break;
      case 'modern_gradient':
        rawHtml = _modernGradientTemplate(subject, formattedBody, shopName, year);
        break;
      case 'elegant':
        rawHtml = _elegantTemplate(subject, formattedBody, shopName, year);
        break;
      case 'elegant_rose':
        rawHtml = _elegantRoseTemplate(subject, formattedBody, shopName, year);
        break;
      case 'elegant_midnight':
        rawHtml = _elegantMidnightTemplate(subject, formattedBody, shopName, year);
        break;
      case 'alert':
        rawHtml = _alertTemplate(subject, formattedBody, shopName, year);
        break;
      case 'alert_orange':
        rawHtml = _alertOrangeTemplate(subject, formattedBody, shopName, year);
        break;
      case 'alert_critical':
        rawHtml = _alertCriticalTemplate(subject, formattedBody, shopName, year);
        break;
      case 'marketing':
        rawHtml = _marketingTemplate(subject, formattedBody, shopName, year);
        break;
      case 'marketing_warm':
        rawHtml = _marketingWarmTemplate(subject, formattedBody, shopName, year);
        break;
      case 'marketing_neon':
        rawHtml = _marketingNeonTemplate(subject, formattedBody, shopName, year);
        break;
      case 'classic_minimal':
        rawHtml = _classicMinimalTemplate(subject, formattedBody, shopName, year);
        break;
      case 'classic_corporate':
        rawHtml = _classicCorporateTemplate(subject, formattedBody, shopName, year);
        break;
      case 'classic':
      default:
        rawHtml = _classicTemplate(subject, formattedBody, shopName, year);
        break;
    }
    return _inlineCss(rawHtml);
  }

  // ═══════════════════════════════════════════════════
  // CLASSIC (3 variantes)
  // ═══════════════════════════════════════════════════

  static String _classicTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: Arial, sans-serif; background-color: #f4f6f8; margin: 0; padding: 20px; color: #333; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
      .header { background-color: #1e3a8a; padding: 30px 20px; text-align: center; color: #ffffff; }
      .header h1 { margin: 0; font-size: 24px; font-weight: 600; }
      .content { padding: 30px; line-height: 1.6; font-size: 16px; }
      .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1></div>
        <div class="content"><h2 style="color: #1e3a8a; font-size: 20px; margin-top: 0;">$subject</h2>$body</div>
        <div class="footer">&copy; $year $shopName. Tous droits réservés.<br>Généré par Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _classicMinimalTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #ffffff; margin: 0; padding: 40px 20px; color: #2d3748; }
      .container { max-width: 580px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 4px; }
      .header { padding: 28px 32px; border-bottom: 2px solid #1a202c; }
      .header h1 { margin: 0; font-size: 16px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: #1a202c; }
      .content { padding: 32px; line-height: 1.7; font-size: 15px; color: #4a5568; }
      .subject { font-size: 22px; font-weight: 600; color: #1a202c; margin: 0 0 20px 0; }
      .footer { padding: 20px 32px; font-size: 11px; color: #a0aec0; border-top: 1px solid #e2e8f0; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">$shopName · $year · Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _classicCorporateTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f0f0; margin: 0; padding: 30px; color: #333; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 0; overflow: hidden; box-shadow: 0 2px 15px rgba(0,0,0,0.08); }
      .header { background: linear-gradient(135deg, #2c3e50, #34495e); padding: 35px 30px; color: #ffffff; }
      .header h1 { margin: 0; font-size: 22px; font-weight: 300; letter-spacing: 1px; }
      .header .tagline { font-size: 12px; opacity: 0.7; margin-top: 6px; text-transform: uppercase; letter-spacing: 2px; }
      .content { padding: 35px 30px; line-height: 1.7; font-size: 15px; color: #555; }
      .subject { font-size: 20px; font-weight: 600; color: #2c3e50; margin: 0 0 20px 0; border-left: 4px solid #2c3e50; padding-left: 16px; }
      .footer { background: #2c3e50; padding: 20px 30px; text-align: center; font-size: 11px; color: #95a5a6; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1><div class="tagline">Communication Officielle</div></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">&copy; $year $shopName — Document confidentiel<br>Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  // ═══════════════════════════════════════════════════
  // MODERN (3 variantes)
  // ═══════════════════════════════════════════════════

  static String _modernTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f1f5f9; margin: 0; padding: 40px 20px; color: #0f172a; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; }
      .header { padding: 40px 30px 20px; text-align: left; }
      .header .logo-badge { display: inline-block; background: #3b82f6; color: white; font-weight: bold; padding: 8px 16px; border-radius: 9999px; font-size: 14px; letter-spacing: 1px; text-transform: uppercase; }
      .content { padding: 10px 30px 40px; line-height: 1.7; font-size: 16px; color: #334155; }
      .title { font-size: 28px; font-weight: 800; color: #0f172a; margin: 20px 0; letter-spacing: -0.5px; }
      .footer { padding: 30px; text-align: center; font-size: 13px; color: #94a3b8; background: #fafafa; }
    </style></head><body>
      <div class="container">
        <div class="header"><div class="logo-badge">$shopName</div></div>
        <div class="content"><div class="title">$subject</div>$body</div>
        <div class="footer">&copy; $year $shopName<br>Propulsé par la technologie Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _modernDarkTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Segoe UI', sans-serif; background-color: #0f172a; margin: 0; padding: 40px 20px; color: #e2e8f0; }
      .container { max-width: 600px; margin: 0 auto; background: #1e293b; border-radius: 16px; overflow: hidden; border: 1px solid #334155; box-shadow: 0 20px 40px rgba(0,0,0,0.3); }
      .header { padding: 35px 30px; border-bottom: 1px solid #334155; }
      .header .badge { display: inline-block; background: #06b6d4; color: #0f172a; font-weight: 800; padding: 6px 14px; border-radius: 6px; font-size: 12px; letter-spacing: 1px; text-transform: uppercase; }
      .content { padding: 30px; line-height: 1.7; font-size: 15px; color: #94a3b8; }
      .title { font-size: 26px; font-weight: 800; color: #f1f5f9; margin: 16px 0; }
      .footer { padding: 20px 30px; text-align: center; font-size: 12px; color: #475569; border-top: 1px solid #334155; }
    </style></head><body>
      <div class="container">
        <div class="header"><div class="badge">$shopName</div></div>
        <div class="content"><div class="title">$subject</div>$body</div>
        <div class="footer">&copy; $year $shopName · Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _modernGradientTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Segoe UI', sans-serif; background-color: #eef2ff; margin: 0; padding: 40px 20px; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 15px 35px rgba(79,70,229,0.1); }
      .header { background: linear-gradient(135deg, #3b82f6, #6366f1, #8b5cf6); padding: 45px 30px; text-align: center; }
      .header h1 { margin: 0; color: #fff; font-size: 26px; font-weight: 800; letter-spacing: 1px; }
      .header p { color: rgba(255,255,255,0.85); margin: 8px 0 0; font-size: 14px; }
      .content { padding: 35px 30px; line-height: 1.7; font-size: 15px; color: #475569; }
      .subject { font-size: 22px; font-weight: 700; color: #1e293b; margin: 0 0 20px; }
      .footer { background: #f8fafc; padding: 20px 30px; text-align: center; font-size: 12px; color: #94a3b8; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1><p>$subject</p></div>
        <div class="content">$body</div>
        <div class="footer">&copy; $year $shopName · Propulsé par Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  // ═══════════════════════════════════════════════════
  // ELEGANT (3 variantes)
  // ═══════════════════════════════════════════════════

  static String _elegantTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Georgia', serif; background-color: #1a1a1a; margin: 0; padding: 40px 20px; color: #333; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; overflow: hidden; border-top: 4px solid #d4af37; box-shadow: 0 15px 35px rgba(0,0,0,0.2); }
      .header { padding: 40px 40px 20px; text-align: center; }
      .header h1 { margin: 0; font-size: 22px; font-weight: normal; letter-spacing: 3px; color: #1a1a1a; text-transform: uppercase; }
      .divider { height: 1px; background: #eaeaea; width: 50px; margin: 20px auto; }
      .content { padding: 20px 50px 50px; line-height: 1.8; font-size: 15px; color: #555; text-align: justify; }
      .subject { font-style: italic; font-size: 18px; color: #d4af37; text-align: center; margin-bottom: 30px; }
      .footer { background-color: #111; padding: 30px; text-align: center; font-size: 11px; color: #888; letter-spacing: 1px; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1><div class="divider"></div></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">$shopName &copy; $year<br><br>DOCUMENT OFFICIEL</div>
      </div>
    </body></html>
    ''';
  }

  static String _elegantRoseTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Georgia', serif; background-color: #fdf2f8; margin: 0; padding: 40px 20px; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; overflow: hidden; border-top: 3px solid #be185d; box-shadow: 0 10px 30px rgba(190,24,93,0.08); }
      .header { padding: 35px 40px 20px; text-align: center; background: linear-gradient(180deg, #fdf2f8, #ffffff); }
      .header h1 { margin: 0; font-size: 20px; font-weight: normal; letter-spacing: 4px; color: #be185d; text-transform: uppercase; }
      .ornament { text-align: center; color: #d4af37; font-size: 18px; margin: 12px 0; }
      .content { padding: 20px 45px 45px; line-height: 1.8; font-size: 15px; color: #6b7280; }
      .subject { font-style: italic; font-size: 17px; color: #be185d; text-align: center; margin-bottom: 25px; }
      .footer { background: #fdf2f8; padding: 25px; text-align: center; font-size: 11px; color: #9ca3af; border-top: 1px solid #fce7f3; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1><div class="ornament">✦</div></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">$shopName · $year<br>Avec élégance, par Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _elegantMidnightTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Georgia', serif; background-color: #0c1222; margin: 0; padding: 40px 20px; }
      .container { max-width: 600px; margin: 0 auto; background: #0f172a; overflow: hidden; border-top: 3px solid #94a3b8; box-shadow: 0 20px 50px rgba(0,0,0,0.5); }
      .header { padding: 40px; text-align: center; }
      .header h1 { margin: 0; font-size: 20px; font-weight: normal; letter-spacing: 5px; color: #cbd5e1; text-transform: uppercase; }
      .silver-line { height: 1px; width: 60px; background: linear-gradient(90deg, transparent, #94a3b8, transparent); margin: 18px auto; }
      .content { padding: 20px 45px 45px; line-height: 1.8; font-size: 15px; color: #94a3b8; }
      .subject { font-style: italic; font-size: 17px; color: #e2e8f0; text-align: center; margin-bottom: 25px; }
      .footer { background: #020617; padding: 25px; text-align: center; font-size: 11px; color: #475569; letter-spacing: 1px; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>$shopName</h1><div class="silver-line"></div></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">$shopName &copy; $year · CONFIDENTIEL</div>
      </div>
    </body></html>
    ''';
  }

  // ═══════════════════════════════════════════════════
  // ALERT (3 variantes)
  // ═══════════════════════════════════════════════════

  static String _alertTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #fef2f2; margin: 0; padding: 30px 10px; color: #111; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; border-left: 6px solid #ef4444; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
      .header { padding: 25px 30px; background: #fef2f2; border-bottom: 1px solid #fee2e2; }
      .header h1 { margin: 0; font-size: 18px; color: #b91c1c; font-weight: 700; }
      .content { padding: 30px; line-height: 1.6; font-size: 15px; color: #374151; }
      .subject { font-size: 20px; font-weight: bold; margin-top: 0; color: #111827; }
      .footer { padding: 20px 30px; background: #f9fafb; font-size: 12px; color: #6b7280; border-top: 1px solid #f3f4f6; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>⚠️ IMPORTANT - $shopName</h1></div>
        <div class="content"><h2 class="subject">$subject</h2>$body</div>
        <div class="footer">Ce message a été généré automatiquement par le système d'alerte de $shopName.</div>
      </div>
    </body></html>
    ''';
  }

  static String _alertOrangeTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: -apple-system, 'Segoe UI', sans-serif; background-color: #fffbeb; margin: 0; padding: 30px 10px; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; border-top: 4px solid #f59e0b; box-shadow: 0 4px 12px rgba(245,158,11,0.1); }
      .header { padding: 24px 28px; background: linear-gradient(135deg, #fef3c7, #fffbeb); display: flex; align-items: center; }
      .header h1 { margin: 0; font-size: 16px; color: #92400e; font-weight: 700; }
      .badge { display: inline-block; background: #f59e0b; color: white; padding: 4px 10px; border-radius: 4px; font-size: 11px; font-weight: 800; margin-bottom: 8px; letter-spacing: 1px; }
      .content { padding: 28px; line-height: 1.6; font-size: 15px; color: #44403c; }
      .subject { font-size: 19px; font-weight: 700; color: #78350f; margin: 0 0 16px; }
      .footer { padding: 18px 28px; background: #fffbeb; font-size: 11px; color: #92400e; border-top: 1px solid #fef3c7; border-radius: 0 0 12px 12px; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1><span class="badge">AVERTISSEMENT</span><br>$shopName</h1></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">⚡ Notification automatique · $shopName · $year</div>
      </div>
    </body></html>
    ''';
  }

  static String _alertCriticalTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: -apple-system, 'Segoe UI', sans-serif; background-color: #450a0a; margin: 0; padding: 30px 10px; }
      .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 8px 25px rgba(220,38,38,0.2); }
      .header { padding: 28px; background: #dc2626; text-align: center; }
      .header h1 { margin: 0; font-size: 20px; color: #ffffff; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; }
      .header p { margin: 6px 0 0; color: rgba(255,255,255,0.8); font-size: 13px; }
      .content { padding: 30px; line-height: 1.6; font-size: 15px; color: #374151; background: #fff; }
      .subject { font-size: 20px; font-weight: 800; color: #991b1b; margin: 0 0 16px; padding-bottom: 12px; border-bottom: 2px solid #fecaca; }
      .footer { padding: 18px 28px; background: #fef2f2; font-size: 11px; color: #991b1b; text-align: center; font-weight: 600; }
    </style></head><body>
      <div class="container">
        <div class="header"><h1>🚨 ALERTE CRITIQUE</h1><p>$shopName</p></div>
        <div class="content"><div class="subject">$subject</div>$body</div>
        <div class="footer">ACTION REQUISE IMMÉDIATEMENT · $year</div>
      </div>
    </body></html>
    ''';
  }

  // ═══════════════════════════════════════════════════
  // MARKETING (3 variantes)
  // ═══════════════════════════════════════════════════

  static String _marketingTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #e0e7ff; margin: 0; padding: 20px; color: #333; }
      .container { max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 30px rgba(79, 70, 229, 0.15); }
      .hero { background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%); padding: 40px 20px; text-align: center; color: white; }
      .hero h1 { margin: 0; font-size: 28px; font-weight: 800; letter-spacing: 1px; }
      .hero p { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
      .content { padding: 40px 30px; line-height: 1.6; font-size: 16px; text-align: center; color: #4b5563; }
      .btn-promo { display: inline-block; padding: 14px 28px; background-color: #4f46e5; color: white; text-decoration: none; border-radius: 50px; font-weight: bold; font-size: 16px; margin-top: 25px; text-transform: uppercase; letter-spacing: 1px; }
      .footer { background-color: #f3f4f6; padding: 25px; text-align: center; font-size: 12px; color: #9ca3af; }
    </style></head><body>
      <div class="container">
        <div class="hero"><h1>$shopName</h1><p>$subject</p></div>
        <div class="content">$body</div>
        <div class="footer">Vous recevez cet email car vous êtes un contact privilégié de $shopName.<br>&copy; $year - Propulsé par Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _marketingWarmTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Helvetica Neue', sans-serif; background-color: #fff7ed; margin: 0; padding: 20px; }
      .container { max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(251,146,60,0.12); }
      .hero { background: linear-gradient(135deg, #f97316, #ef4444); padding: 45px 30px; text-align: center; color: white; }
      .hero h1 { margin: 0; font-size: 28px; font-weight: 800; }
      .hero p { margin: 10px 0 0; font-size: 15px; opacity: 0.9; }
      .content { padding: 35px 30px; line-height: 1.7; font-size: 15px; text-align: center; color: #57534e; }
      .btn { display: inline-block; padding: 12px 28px; background: linear-gradient(135deg, #f97316, #ef4444); color: white; text-decoration: none; border-radius: 50px; font-weight: bold; margin-top: 20px; font-size: 14px; letter-spacing: 0.5px; }
      .footer { background: #fff7ed; padding: 22px; text-align: center; font-size: 11px; color: #a8a29e; }
    </style></head><body>
      <div class="container">
        <div class="hero"><h1>$shopName</h1><p>$subject</p></div>
        <div class="content">$body<br><a href="#" class="btn">EN PROFITER</a></div>
        <div class="footer">Contact privilégié de $shopName · &copy; $year · Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _marketingNeonTemplate(String subject, String body, String shopName, int year) {
    return '''
    <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: 'Segoe UI', sans-serif; background-color: #09090b; margin: 0; padding: 20px; }
      .container { max-width: 600px; margin: 20px auto; background: #18181b; border-radius: 16px; overflow: hidden; border: 1px solid #22c55e33; box-shadow: 0 0 40px rgba(34,197,94,0.08); }
      .hero { background: linear-gradient(135deg, #052e16, #14532d); padding: 45px 30px; text-align: center; }
      .hero h1 { margin: 0; font-size: 28px; font-weight: 800; color: #22c55e; letter-spacing: 1px; }
      .hero p { margin: 10px 0 0; font-size: 15px; color: #86efac; }
      .content { padding: 35px 30px; line-height: 1.7; font-size: 15px; text-align: center; color: #a1a1aa; }
      .btn { display: inline-block; padding: 12px 28px; background: #22c55e; color: #052e16; text-decoration: none; border-radius: 8px; font-weight: 800; margin-top: 20px; font-size: 14px; letter-spacing: 1px; text-transform: uppercase; }
      .footer { background: #09090b; padding: 22px; text-align: center; font-size: 11px; color: #52525b; border-top: 1px solid #27272a; }
    </style></head><body>
      <div class="container">
        <div class="hero"><h1>$shopName</h1><p>$subject</p></div>
        <div class="content">$body<br><a href="#" class="btn">DÉCOUVRIR</a></div>
        <div class="footer">$shopName · &copy; $year · Danaya+</div>
      </div>
    </body></html>
    ''';
  }

  static String _inlineCss(String html) {
    // 1. Locate <style> tag content
    final styleRegex = RegExp(r'<style>(.*?)</style>', dotAll: true);
    final match = styleRegex.firstMatch(html);
    if (match == null) return html;

    final css = match.group(1) ?? '';

    // Remove style tag from html
    var cleanHtml = html.replaceAll(styleRegex, '');

    // Parse selector and declaration blocks
    // Format: selector { declarations }
    final ruleRegex = RegExp(r'([^{]+)\{([^}]+)\}', dotAll: true);
    final rules = ruleRegex.allMatches(css);

    final Map<String, String> styleMap = {};
    for (final rule in rules) {
      final selectorsList = rule.group(1)!.split(',');
      final styles = rule.group(2)!.trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
      for (var sel in selectorsList) {
        styleMap[sel.trim()] = styles;
      }
    }

    // Replace classes with styles
    final classRegex = RegExp(r'''class=["']([^"']+)["']''');
    cleanHtml = cleanHtml.replaceAllMapped(classRegex, (m) {
      final classNamesAttr = m.group(1) ?? '';
      final classNames = classNamesAttr.split(' ');

      var combinedStyles = '';
      for (final className in classNames) {
        final dotClass = '.$className';
        var foundStyle = '';
        styleMap.forEach((selector, value) {
          if (selector == dotClass || selector.endsWith(' $dotClass')) {
            foundStyle += '$value ';
          }
        });
        if (foundStyle.isNotEmpty) {
          combinedStyles += foundStyle;
        }
      }

      if (combinedStyles.isNotEmpty) {
        return 'class="$classNamesAttr" style="${combinedStyles.trim()}"';
      }
      return m.group(0)!;
    });

    // Inline body tag
    if (styleMap.containsKey('body')) {
      cleanHtml = cleanHtml.replaceAll('<body', '<body style="${styleMap['body']}"');
    }

    // Inline inner elements like h1 or p inside components
    styleMap.forEach((selector, declarations) {
      if (selector.endsWith(' h1')) {
        cleanHtml = cleanHtml.replaceAll('<h1>', '<h1 style="$declarations">');
      }
      if (selector.endsWith(' p')) {
        cleanHtml = cleanHtml.replaceAll('<p>', '<p style="$declarations">');
      }
    });

    return cleanHtml;
  }
}
