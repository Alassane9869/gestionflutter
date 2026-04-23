import 'dart:convert';

String getCustomerDisplayHtml(
  String shopName,
  String ip,
  int port,
  String theme, {
  String currencySymbol = 'F',
  String locale = 'fr-FR',
  String syncKey = '',
  bool enableTicker = true,
  bool use3D = false,
  List<Map<String, dynamic>> products = const [],
  List<String> messages = const [],
}) {
  final encodedKey = Uri.encodeComponent(syncKey);
  final productsJson = products.where((p) => p['image_path'] != null && p['image_path'].toString().isNotEmpty).map((p) {
    final imagePath = p['image_path'] as String;
    final imageName = imagePath.split(RegExp(r'[/\\]')).last;
    return {
      'name': p['name'],
      'price': p['sellingPrice'],
      'image': imageName,
    };
  }).toList();
  
  final tickerHtml = enableTicker 
    ? messages.map((m) => '<div class="ticker-item"><span style="color:#fff;">⚡</span> $m</div>').join('')
    : '';

  return '''
<!DOCTYPE html>
<html lang="${locale.split('-')[0]}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Affichage Client — $shopName</title>
  
  <!-- Apple-Tier Professional Fonts -->
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,600;0,800;1,600&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- NO VANTA CDN. 100% OFFLINE DANAYAFX ENGINE INJECTED -->

  <style>
    :root {
      --bg: #000000;
      --panel-bg: rgba(255, 255, 255, 0.98);
      --text: #111827;
      --accent: #D4AF37;
      --muted: #6B7280;
      --border: rgba(0, 0, 0, 0.08);
      --brand-text: #ffffff;
      --brand-accent: #D4AF37;
    }

    * { margin:0; padding:0; box-sizing:border-box; -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale; }
    
    body { 
      background: var(--bg); 
      color: var(--text); 
      height: 100vh; width: 100vw; overflow: hidden; 
      display: grid; grid-template-columns: 1fr 420px; 
      font-family: 'Inter', system-ui, sans-serif;
    }
    
    /* ================= LEFT PANE: BRAND & 3D ================= */
    .left-brand { 
      position: relative; 
      display: flex; flex-direction: column; justify-content: space-between; 
      padding: 60px 80px; 
      overflow: hidden;
    }
    
    /* DanayaFX Engine Styles */
    #danayafx-canvas {
      position: absolute; inset: 0; z-index: 0; pointer-events: none; opacity: 0; transition: opacity 2s ease;
    }
    #danayafx-canvas.active { opacity: 0.85; } /* Rendu puissant sans éblouir */
    
    #danayafx-aura {
      position: absolute; inset: 0; z-index: 0; pointer-events: none; overflow: hidden; opacity: 0; transition: opacity 2s ease; filter: blur(50px);
    }
    #danayafx-aura.active { opacity: 1; } /* Rendu vibrant */
    
    .aura-orb {
      position: absolute; border-radius: 50%; opacity: 0.95; mix-blend-mode: screen;
      animation: floatAura 20s infinite ease-in-out alternate;
    }
    .aura-orb.orb-1 { width: 55vw; height: 55vw; top: -10vw; left: -10vw; background: var(--accent); animation-duration: 25s; }
    .aura-orb.orb-2 { width: 45vw; height: 45vw; bottom: -5vw; right: 5vw; background: var(--brand-accent); animation-duration: 18s; animation-delay: -5s; }
    .aura-orb.orb-3 { width: 50vw; height: 50vw; top: 15vh; left: 15vw; background: var(--muted); opacity: 0.8; animation-duration: 30s; animation-delay: -10s; }
    
    @keyframes floatAura {
      0% { transform: scale(1) translate(0, 0); }
      50% { transform: scale(1.1) translate(4vw, -4vh); }
      100% { transform: scale(0.9) translate(-4vw, 4vh); }
    }

    /* Gradient to ensure text pops cleanly over 3D */
    .ad-overlay {
      position: absolute; inset: 0; z-index: 1;
      background: linear-gradient(135deg, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0.1) 60%, transparent 100%);
      pointer-events: none;
    }

    /* Left Brand Content */
    .brand-content { position: relative; z-index: 10; display: flex; flex-direction: column; height: 100%; color: var(--brand-text); }
    
    .brand-top { 
      display: flex; align-items: center; gap: 12px; 
      padding: 8px 16px; border-radius: 50px;
      background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1);
      text-transform: uppercase; letter-spacing: 2px; font-weight: 800; font-size: 14px; 
      margin-bottom: 24px; color: var(--brand-accent);
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
    }
    .dot { width: 10px; height: 10px; background: #ef4444; border-radius: 50%; box-shadow: 0 0 10px currentColor; }
    .dot.online { background: #10b981; animation: pulse 2s infinite; }
    
    /* Layout for Center */
    .center-content { 
      flex: 1; display: flex; flex-direction: column; justify-content: center; align-items: flex-start; gap: 50px; 
    }

    /* Slogans */
    .slogan-main { font-family: 'Playfair Display', serif; font-size: clamp(40px, 6vw, 90px); font-weight: 800; line-height: 1.05; margin-bottom: 15px; letter-spacing: -1px; text-shadow: 0 5px 20px rgba(0,0,0,0.3); }
    .slogan-sub { font-size: 22px; font-weight: 300; letter-spacing: 0.5px; opacity: 0.9; text-shadow: 0 2px 10px rgba(0,0,0,0.3); }
    
    /* Precision Widget Card (The "Small" Ad) */
    .ad-card {
      display: flex; align-items: center; gap: 24px;
      padding: 24px 32px 24px 24px;
      border-radius: 20px;
      background: var(--panel-bg);
      box-shadow: 0 15px 40px rgba(0,0,0,0.2);
      border: 1px solid var(--border);
      border-left: 5px solid var(--brand-accent);
      min-width: 350px;
      max-width: 450px;
      transition: opacity 0.6s ease, transform 0.6s cubic-bezier(0.16, 1, 0.3, 1);
      opacity: 0; transform: translateY(20px);
    }
    .ad-card.active { opacity: 1; transform: translateY(0); }
    .ad-card img { width: 120px; height: 120px; border-radius: 12px; object-fit: cover; background: var(--border); box-shadow: 0 8px 20px rgba(0,0,0,0.15); image-rendering: -webkit-optimize-contrast; image-rendering: high-quality; transform: translateZ(0); filter: contrast(1.02) brightness(1.03); }
    .ad-subtitle { font-size: 10px; font-weight: 800; letter-spacing: 3px; color: var(--muted); margin-bottom: 8px; text-transform: uppercase; }
    .ad-title { font-family: 'Inter', sans-serif; font-size: 20px; font-weight: 800; color: var(--text); margin-bottom: 6px; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 250px; }
    .ad-price { font-size: 18px; font-weight: 700; color: var(--brand-accent); }

    /* Quote Area */
    .quote-area { border-left: 2px solid var(--brand-accent); padding-left: 20px; max-width: 80%; opacity: 0; transition: opacity 1s ease; margin-bottom: 30px;}
    .quote-area.visible { opacity: 1; }
    .quote-text { font-family: 'Playfair Display', serif; font-style: italic; font-size: 18px; line-height: 1.5; margin-bottom: 8px; text-shadow: 0 2px 5px rgba(0,0,0,0.3); }
    .quote-author { font-size: 10px; text-transform: uppercase; letter-spacing: 3px; font-weight: 700; opacity: 0.7; }

    /* ================= RIGHT PANE: CLINICAL RECEIPT ================= */
    .right-pane { 
      position: relative; background: var(--panel-bg); border-left: 1px solid var(--border); 
      display: flex; flex-direction: column; justify-content: space-between; z-index: 20; 
      backdrop-filter: blur(40px); box-shadow: -15px 0 50px rgba(0,0,0,0.08);
    }
    
    .cart-header { padding: 40px 30px 20px; font-weight: 700; font-size: 13px; letter-spacing: 3px; color: var(--muted); text-transform: uppercase; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); }
    .cart-count { background: var(--border); color: var(--text); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 800; }
    
    .cart-list { flex: 1; overflow-y: auto; padding: 15px 30px; scrollbar-width: none; }
    .cart-list::-webkit-scrollbar { display: none; }
    
    /* Clinical List Rows */
    .item { 
      display: grid; grid-template-columns: 46px 1fr auto; gap: 16px; align-items: center; 
      padding: 18px 0; border-bottom: 1px solid var(--border);
      animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1) both; opacity: 0;
    }
    .item:last-child { border-bottom: none; }
    
    .item-img { width: 46px; height: 46px; border-radius: 10px; object-fit: cover; background: var(--border); image-rendering: -webkit-optimize-contrast; image-rendering: high-quality; transform: translateZ(0); }
    .item-info { overflow: hidden; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
    .item-name { font-weight: 600; font-size: 14px; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; letter-spacing: -0.2px; }
    .item-qty-price { font-size: 12px; color: var(--muted); font-weight: 500; }
    .item-total { font-family: 'Inter', sans-serif; font-weight: 800; font-size: 15px; text-align: right; color: var(--text); letter-spacing: -0.5px; }

    /* Grand Total Box */
    .totals-area { 
      padding: 30px; 
      background: var(--panel-bg); 
      border-top: 1px solid var(--border); 
      position: relative;
    }
    .totals-area::before {
      content: ''; position: absolute; top: -1px; left: 0; width: 40%; height: 2px; background: var(--accent);
    }
    
    .total-row { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px; }
    .total-label { font-size: 11px; font-weight: 800; letter-spacing: 3px; color: var(--muted); text-transform: uppercase; }
    .total-amount { font-family: 'Playfair Display', serif; font-size: 40px; font-weight: 800; color: var(--text); line-height: 1; letter-spacing: -1px; transition: transform 0.2s ease; }
    .total-amount.active { transform: scale(1.02); color: var(--accent); }
    .total-words { font-size: 11px; font-weight: 600; color: var(--muted); margin-top: 15px; text-transform: uppercase; overflow-wrap: break-word; line-height: 1.5; letter-spacing: 0.5px; }

    /* Marketing Banner (Recruitment) */
    .marketing-banner {
      margin-top: 20px;
      padding: 16px;
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.1) 0%, rgba(212, 175, 55, 0.05) 100%);
      border: 1px dashed var(--brand-accent);
      border-radius: 12px;
      text-align: center;
      display: none;
      animation: pulse-soft 3s infinite ease-in-out;
    }
    .marketing-banner.active { display: block; animation: slideUp 0.5s ease forwards; }
    .mkt-text { font-size: 13px; font-weight: 700; color: var(--text); line-height: 1.4; }
    .mkt-points { color: var(--brand-accent); font-weight: 900; font-size: 16px; }

    @keyframes pulse-soft {
      0% { box-shadow: 0 0 0 0 rgba(212, 175, 55, 0.2); }
      70% { box-shadow: 0 0 0 10px rgba(212, 175, 55, 0); }
      100% { box-shadow: 0 0 0 0 rgba(212, 175, 55, 0); }
    }

    /* Empty Cart State (Professional Wait Screen) */
    .empty-cart { flex: 1; display: none; flex-direction: column; align-items: center; justify-content: center; padding: 40px; text-align: center; opacity: 0; transition: opacity 0.5s; }
    .empty-cart.active { display: flex; opacity: 1; }
    .empty-icon { width: 64px; height: 64px; border-radius: 50%; background: var(--border); display: flex; align-items: center; justify-content: center; margin-bottom: 24px; color: var(--muted); }
    .empty-icon svg { width: 28px; height: 28px; opacity: 0.7; }
    .empty-title { font-size: 16px; font-weight: 600; color: var(--text); margin-bottom: 8px; letter-spacing: -0.3px; }
    .empty-desc { font-size: 13px; color: var(--muted); line-height: 1.5; }

    /* Ticker Fix (Single Line scrolling properly) */
    .ticker-wrapper { position: fixed; bottom: 0; left: 0; width: calc(100vw - 420px); height: 36px; background: rgba(0,0,0,0.6); backdrop-filter: blur(10px); z-index: 30; overflow: hidden; display: flex; align-items: center; }
    .ticker { display: flex; align-items: center; white-space: nowrap; animation: ticker 40s linear infinite; padding-left: 100vw; }
    .ticker-item { display: inline-flex; align-items: center; gap: 8px; margin-right: 150px; font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--brand-accent); white-space: nowrap; }

    /* Premium Celebration Modal */
    .celebration { position: fixed; inset: 0; background: rgba(0,0,0,0.7); backdrop-filter: blur(15px); z-index: 1000; display: none; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.4s ease; }
    .modal { background: var(--panel-bg); padding: 40px; border-radius: 20px; width: 400px; text-align: center; box-shadow: 0 40px 80px rgba(0,0,0,0.2); border: 1px solid var(--border); transform: translateY(20px); transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1); }
    .celebration.active .modal { transform: translateY(0); }
    .m-icon { width: 56px; height: 56px; background: rgba(16, 185, 129, 0.1); color: #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; }
    .m-title { font-size: 22px; font-weight: 700; color: var(--text); margin-bottom: 6px; letter-spacing: -0.5px; }
    .m-desc { font-size: 14px; color: var(--muted); margin-bottom: 30px; }
    .m-row { display: flex; justify-content: space-between; margin-bottom: 14px; color: var(--muted); font-size: 14px; font-weight: 500; }
    .m-row span:last-child { color: var(--text); font-weight: 600; }
    .m-total { display: flex; justify-content: space-between; align-items: center; color: var(--text); font-weight: 700; font-size: 18px; border-top: 1px solid var(--border); padding-top: 18px; margin-top: 18px; }
    .m-total span:last-child { color: var(--accent); font-size: 22px; }

    @keyframes slideUp { from { opacity: 0; transform: translateY(15px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes ticker { 0% { transform: translateX(0); } 100% { transform: translateX(-100%); } }
    @keyframes pulse { 0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.4); } 70% { box-shadow: 0 0 0 10px rgba(16, 185, 129, 0); } 100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); } }
  </style>
</head>
<body>

  <div class="left-brand">
    <canvas id="danayafx-canvas"></canvas>
    <div id="danayafx-aura">
      <div class="aura-orb orb-1"></div>
      <div class="aura-orb orb-2"></div>
      <div class="aura-orb orb-3"></div>
    </div>
    
    <div class="ad-overlay" id="theme-overlay"></div>
    
    <div class="brand-content">
      <div class="brand-top"><span class="dot" id="status-dot"></span> <span id="shop-label">$shopName</span></div>
      
      <div class="center-content">
        <!-- DEFAULT BRANDING -->
        <div id="default-branding" class="default-branding">
          <div class="slogan-main" id="slogan-1">Danaya+<br>Excellence.</div>
          <div class="slogan-sub">La gestion intelligente de votre stock.</div>
        </div>

        <!-- SMALL PRODUCT SPOTLIGHT WIDGET -->
        <div id="ad-branding" class="ad-card" style="display: none;">
          <img id="ad-img" src="" alt="Produit">
          <div class="ad-text-wrapper">
             <div class="ad-subtitle">PRODUIT VEDETTE</div>
             <div class="ad-title" id="ad-title">Nom Produit</div>
             <div class="ad-price" id="ad-price">0 F CFA</div>
          </div>
        </div>
      </div>

      <!-- QUOTE AREA -->
      <div class="quote-area" id="quote-area">
        <div class="quote-text" id="quote-text">La qualité n'est pas un acte, c'est une habitude.</div>
        <div class="quote-author" id="quote-author">ARISTOTE</div>
      </div>
    </div>
  </div>

  <div class="right-pane">
    <div class="cart-header">
      <span>Ticket de caisse</span>
      <span class="cart-count" id="cart-count">0</span>
    </div>
    
    <div class="cart-list" id="list"></div>
    
    <!-- PROFESSIONAL EMPTY CART WAIT SCREEN -->
    <div class="empty-cart active" id="empty-cart">
      <div class="empty-icon">
        <svg fill="currentColor" viewBox="0 0 24 24"><path d="M16 6V4C16 1.79086 14.2091 0 12 0C9.79086 0 8 1.79086 8 4V6H0V20C0 22.2091 1.79086 24 4 24H20C22.2091 24 24 22.2091 24 20V6H16ZM10 4C10 2.89543 10.8954 2 12 2C13.1046 2 14 2.89543 14 4V6H10V4ZM22 20C22 21.1046 21.1046 22 20 22H4C2.89543 22 2 21.1046 2 20V8H8V10C8 10.5523 8.44772 11 9 11C9.55228 11 10 10.5523 10 10V8H14V10C14 10.5523 14.4477 11 15 11C15.5523 11 16 10.5523 16 10V8H22V20Z"/></svg>
      </div>
      <div class="empty-title">Votre panier est vide</div>
      <div class="empty-desc">Les articles scannés<br>s'afficheront ici.</div>
    </div>
    
    <div class="totals-area">
      <div class="total-row">
        <span class="total-label">À Payer</span>
      </div>
      <div class="total-amount" id="total">0 $currencySymbol</div>
      <div class="total-words" id="total-words">Zéro $currencySymbol</div>
    </div>
    
    <div id="marketing-banner" class="marketing-banner" style="margin: 0 30px 30px;">
      <div class="mkt-text">🎁 Vous pourriez gagner <span class="mkt-points" id="pot-points">0</span> points sur cet achat !<br><span style="font-size: 10px; opacity: 0.7; font-weight: 500;">Inscrivez-vous maintenant au comptoir.</span></div>
    </div>
  </div>

  <div class="ticker-wrapper" id="ticker-wrap" style="display: none;">
    <div class="ticker">
      $tickerHtml
    </div>
  </div>

  <div class="celebration" id="celebration">
    <div class="modal">
      <div class="m-icon">
        <svg fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"></path></svg>
      </div>
      <div class="m-title">Paiement Réussi</div>
      <div class="m-desc">Merci pour votre confiance.</div>
      <div class="m-row"><span>Total Réglé</span> <span id="rec-total">0</span></div>
      <div class="m-row"><span>Montant Versé</span> <span id="rec-paid">0</span></div>
      <div class="m-row" id="row-points-gained" style="display: none;"><span style="color: var(--brand-accent); font-weight: 800;">Points Gagnés ⭐</span> <span id="rec-points-gained" style="color: var(--brand-accent); font-weight: 800;">0</span></div>
      <div class="m-row" id="row-points-redeemed" style="display: none;"><span style="color: #ef4444; font-weight: 800;">Réduction Fidélité</span> <span id="rec-points-redeemed" style="color: #ef4444; font-weight: 800;">0</span></div>
      <div id="row-missing-points" style="display: none; margin-top: 10px; padding: 10px; background: rgba(212, 175, 55, 0.1); border-radius: 8px; border: 1px dashed var(--brand-accent);">
         <div style="font-size: 12px; color: var(--text); font-weight: 600;">🎁 Dommage ! Vous avez manqué <span id="rec-missing-points" style="color: var(--brand-accent); font-weight: 800;">0</span> points.</div>
         <div style="font-size: 10px; color: var(--muted);">Inscrivez-vous pour ne plus rien rater !</div>
      </div>
      <div class="m-total"><span>Monnaie Rendue</span> <span id="rec-change">0</span></div>
    </div>
  </div>

<script>
  // High-End Themes with DanayaFX Mapping
  const themes = {
    'theme-luxury': { bg:'#121212', p:'#ffffff', txt:'#111827', a:'#D4AF37', m:'#6B7280', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#D4AF37', s:'Luxury Gold ✨', sub:'L’Art de l’Exception', q:'Le raffinement est la forme ultime de l’élégance.', qa:'ANONYME', eff:'AURA' },
    'theme-minimal': { bg:'#f8fafc', p:'#ffffff', txt:'#111827', a:'#111827', m:'#64748b', b:'rgba(0,0,0,0.06)', bt:'#111827', ba:'#111827', s:'Pureté & Élégance ✨', sub:'La Beauté du Simple', q:'La simplicité est la sophistication suprême.', qa:'DA VINCI', eff:'NET' },
    'theme-neon': { bg:'#020617', p:'#0f172a', txt:'#f8fafc', a:'#38bdf8', m:'#94a3b8', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#38bdf8', s:'Futur & Énergie ✨', sub:'L’Énergie du Futur', q:'Innover, c’est créer le monde de demain.', qa:'JOBS', eff:'NET' },
    'theme-corporate': { bg:'#0f172a', p:'#ffffff', txt:'#0f172a', a:'#3b82f6', m:'#64748b', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#60a5fa', s:'Performance & Pro ✨', sub:'Votre Partenaire Succès', q:'La qualité n’est pas un acte, c’est une habitude.', qa:'ARISTOTE', eff:'NET' },
    'theme-nature': { bg:'#064e3b', p:'#ffffff', txt:'#064e3b', a:'#10b981', m:'#64748b', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#34d399', s:'Zen & Organique 🌿', sub:'Sérénité Partagée', q:'La nature ne se presse pas, pourtant tout est accompli.', qa:'LAO TZU', eff:'AURA' },
    'theme-sunset': { bg:'#451a03', p:'#ffffff', txt:'#451a03', a:'#f59e0b', m:'#78350f', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#fbbf24', s:'Chaleur Solaire 🌅', sub:'Chaleur de l’Instant', q:'Chaque client est un nouveau rayon de soleil.', qa:'DANAYA+', eff:'AURA' },
    'theme-midnight': { bg:'#000000', p:'#09090b', txt:'#fafafa', a:'#a855f7', m:'#a1a1aa', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#d8b4fe', s:'Midnight OLED ✨', sub:'Profondeur & Distinction', q:'L’élégance est la seule beauté qui ne se fane jamais.', qa:'HEPBURN', eff:'NET' },
    'theme-rose': { bg:'#4c0519', p:'#ffffff', txt:'#4c0519', a:'#e11d48', m:'#9f1239', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#fb7185', s:'Rose & Champagne 🌸', sub:'Éclat & Douceur', q:'La courtoisie est la clef d’un service d’exception.', qa:'PROVERBE', eff:'AURA' },
    'theme-emerald': { bg:'#083344', p:'#ffffff', txt:'#083344', a:'#06b6d4', m:'#164e63', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#22d3ee', s:'Émeraude & Cyan 🌊', sub:'Fraîcheur & Fluidité', q:'Le secret du succès est de naviguer avec précision.', qa:'DANAYA+', eff:'AURA' },
    'theme-amethyst': { bg:'#3b0764', p:'#ffffff', txt:'#3b0764', a:'#a855f7', m:'#581c87', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#c084fc', s:'Royauté Améthyste ✨', sub:'Éclat Mystique', q:'La perfection réside dans la passion du détail.', qa:'DA VINCI', eff:'AURA' },
    'theme-cyberpunk': { bg:'#3f000f', p:'#0a0a0a', txt:'#ffe4e6', a:'#e11d48', m:'#be123c', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#fb7185', s:'Crimson Logic ⚡', sub:'Puissance & Précision', q:'La vitesse sans style est une erreur.', qa:'ROOSEVELT', eff:'NET' },
    'theme-arctic': { bg:'#0c4a6e', p:'#ffffff', txt:'#0c4a6e', a:'#0284c7', m:'#0369a1', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#7dd3fc', s:'Arctic Frost ❄️', sub:'Clarté & Précision', q:'La transparence est le fondement de la confiance.', qa:'CONFUCIUS', eff:'AURA' }
  };

  function applyTheme(id) {
    const t = themes[id] || themes['theme-luxury'];
    window._currentTheme = id;
    const r = document.documentElement.style;
    
    // Glassmorphism transparent cart adaptation
    let panelBg = t.p;
    if(t.p === '#ffffff') panelBg = 'rgba(255, 255, 255, 0.95)';
    else if(t.p === '#0f172a') panelBg = 'rgba(15, 23, 42, 0.9)';
    else if(t.p === '#09090b') panelBg = 'rgba(9, 9, 11, 0.9)';
    else if(t.p === '#0a0a0a') panelBg = 'rgba(10, 10, 10, 0.9)'; 
    
    // Tweak overlay for light vs dark bg
    const overlay = document.getElementById('theme-overlay');
    if (id === 'theme-minimal') {
      overlay.style.background = 'linear-gradient(135deg, rgba(255,255,255,0.95) 0%, rgba(255,255,255,0.6) 40%, transparent 100%)';
    } else {
      overlay.style.background = 'linear-gradient(135deg, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0.1) 60%, transparent 100%)';
    }

    r.setProperty('--bg', t.bg);
    r.setProperty('--panel-bg', panelBg);
    r.setProperty('--text', t.txt);
    r.setProperty('--accent', t.a);
    r.setProperty('--muted', t.m);
    r.setProperty('--border', t.b);
    r.setProperty('--brand-text', t.bt);
    r.setProperty('--brand-accent', t.ba);
    
    document.getElementById('slogan-1').innerHTML = t.s.replace(' & ', '<br>& ');
    document.querySelector('.slogan-sub').innerText = t.sub;

    // Fast Quote Update
    document.getElementById('quote-text').innerText = t.q;
    document.getElementById('quote-author').innerText = t.qa;
    document.getElementById('quote-area').style.opacity = '1';
    
    // Launch Offline FX Engine
    toggleDanayaFX(true);
  }

  // --- DANAYAFX OFFLINE ENGINE (0 CND, 0 BOGUE) ---
  class DanayaFXConstellation {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.color = {r:255, g:255, b:255};
      this.particles = [];
      this.isActive = false;
      this.resize();
      window.addEventListener('resize', () => this.resize());
    }
    hexToRgb(hex) {
      if(!hex) return null;
      let r = 0, g = 0, b = 0;
      if(hex.length === 4) {
        r = parseInt(hex[1] + hex[1], 16);
        g = parseInt(hex[2] + hex[2], 16);
        b = parseInt(hex[3] + hex[3], 16);
      } else if(hex.length === 7) {
        r = parseInt(hex[1] + hex[2], 16);
        g = parseInt(hex[3] + hex[4], 16);
        b = parseInt(hex[5] + hex[6], 16);
      }
      return {r, g, b};
    }
    resize() {
      this.canvas.width = this.canvas.parentElement.clientWidth;
      this.canvas.height = this.canvas.parentElement.clientHeight;
      this.initParticles();
    }
    initParticles() {
      this.particles = [];
      const numParticles = Math.min(Math.floor((this.canvas.width * this.canvas.height) / 7000), 160); // Plus de particules
      for(let i=0; i<numParticles; i++) {
        this.particles.push({
          x: Math.random() * this.canvas.width,
          y: Math.random() * this.canvas.height,
          vx: (Math.random() - 0.5) * 0.6,
          vy: (Math.random() - 0.5) * 0.6,
          radius: Math.random() * 2.5 + 1.0 // Points plus gros
        });
      }
    }
    start() {
      if(this.isActive) return;
      this.isActive = true;
      this.canvas.classList.add('active');
      this.animate();
    }
    stop() {
      this.isActive = false;
      this.canvas.classList.remove('active');
    }
    updateColor(hex) {
       this.color = this.hexToRgb(hex) || this.color;
    }
    animate() {
      if(!this.isActive) return;
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      const r = this.color.r;
      const g = this.color.g;
      const b = this.color.b;
      
      for(let i=0; i<this.particles.length; i++) {
        let p = this.particles[i];
        p.x += p.vx; p.y += p.vy;
        if(p.x < 0 || p.x > this.canvas.width) p.vx *= -1;
        if(p.y < 0 || p.y > this.canvas.height) p.vy *= -1;
        
        this.ctx.beginPath();
        this.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ', 1)'; // Opacité max pour les points
        this.ctx.fill();
        
        for(let j=i+1; j<this.particles.length; j++) {
          let p2 = this.particles[j];
          let dist = Math.hypot(p.x - p2.x, p.y - p2.y);
          if(dist < 160) { // Distance de connexion plus grande
            this.ctx.beginPath();
            this.ctx.moveTo(p.x, p.y);
            this.ctx.lineTo(p2.x, p2.y);
            this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + ((1 - dist/160) * 0.7) + ')';
            this.ctx.lineWidth = 1.2; // Lignes plus épaisses et visibles
            this.ctx.stroke();
          }
        }
      }
      requestAnimationFrame(() => this.animate());
    }
  }

  let fxEngine = null;

  function toggleDanayaFX(enable) {
    const aura = document.getElementById('danayafx-aura');
    const canvas = document.getElementById('danayafx-canvas');
    const theme = themes[window._currentTheme] || themes['theme-luxury'];
    
    if(!enable) {
      if(fxEngine) fxEngine.stop();
      aura.classList.remove('active');
      return;
    }
    
    if(theme.eff === 'NET') {
      aura.classList.remove('active');
      if(!fxEngine) fxEngine = new DanayaFXConstellation(canvas);
      fxEngine.updateColor(theme.a);
      fxEngine.start();
    } else if(theme.eff === 'AURA') {
      if(fxEngine) fxEngine.stop();
      aura.classList.add('active');
    }
  }

  // --- TICKER LOGIC ---
  const tickerHtmlInput = `$tickerHtml`;
  if (tickerHtmlInput.trim() !== '') {
    document.getElementById('ticker-wrap').style.display = 'flex';
  }

  // --- AUDIO ENGINE ---
  const sounds = {
    'scan_success': 'https://assets.mixkit.co/sfx/preview/mixkit-interface-click-1126.mp3',
    'sale_success': 'https://assets.mixkit.co/sfx/preview/mixkit-cash-register-purchase-2257.mp3'
  };

  function playSound(type) {
    if(!sounds[type]) return;
    try {
      const audio = new Audio(sounds[type]);
      audio.volume = 0.5;
      audio.play().catch(e => console.log('Audio error:', e));
    } catch(e) {}
  }

  // --- AD WIDGET LOGIC ---
  const products = ${json.encode(productsJson)};
  let currentAdIdx = 0;

  function cycleAds() {
    if(!products || products.length === 0) return;
    const p = products[currentAdIdx];
    const imagePath = '/images/' + p.image;
    const adBranding = document.getElementById('ad-branding');
    
    // Fade out
    adBranding.classList.remove('active');
    
    setTimeout(() => {
      const img = new Image();
      img.onload = () => {
        adBranding.style.display = 'flex';
        document.getElementById('ad-img').src = imagePath;
        document.getElementById('ad-title').innerText = p.name;
        document.getElementById('ad-price').innerText = fmt(p.price);
        
        // Fade in
        setTimeout(() => adBranding.classList.add('active'), 50);
        currentAdIdx = (currentAdIdx + 1) % products.length;
      };
      img.onerror = () => { currentAdIdx = (currentAdIdx + 1) % products.length; };
      img.src = imagePath;
    }, 600);
  }

  const currency = '$currencySymbol';
  const locale = '$locale';
  const formatter = new Intl.NumberFormat(locale, { minimumFractionDigits:0, maximumFractionDigits:2 });
  function fmt(n) { return formatter.format(n) + ' ' + currency; }
  
  function setTotal(n) {
    const el = document.getElementById('total');
    const wordsEl = document.getElementById('total-words');
    const val = fmt(n);
    el.innerText = val;
    wordsEl.innerText = numberToWordsFr(n) + ' ' + currency;
    el.classList.add('active');
    setTimeout(() => el.classList.remove('active'), 200);
  }

  function numberToWordsFr(n) {
    n = Math.round(n); if(n===0) return 'Zéro';
    const u = ['','un','deux','trois','quatre','cinq','six','sept','huit','neuf','dix','onze','douze','treize','quatorze','quinze','seize','dix-sept','dix-huit','dix-neuf'];
    const t = ['','','vingt','trente','quarante','cinquante','soixante','soixante-dix','quatre-vingt','quatre-vingt-dix'];
    function sub100(v) {
      if(v<20) return u[v];
      let ten=Math.floor(v/10), unit=v%10;
      if(ten===7) return unit===1 ? 'soixante et onze' : 'soixante-'+u[10+unit];
      if(ten===9) return 'quatre-vingt-'+u[10+unit];
      if(unit===0) return ten===8 ? 'quatre-vingts' : t[ten];
      if(unit===1 && ten!==8) return t[ten]+' et un';
      return t[ten]+'-'+u[unit];
    }
    function sub1000(v) {
      let h=Math.floor(v/100), rm=v%100, s='';
      if(h>0) s += (h===1?'cent ':u[h]+' cent' + (rm===0?'s ':' '));
      if(rm>0) s += sub100(rm);
      return s.trim();
    }
    function dec(v) {
      let tr=Math.floor(v/1e12), b=Math.floor((v%1e12)/1e9), m=Math.floor((v%1e9)/1e6), k=Math.floor((v%1e6)/1e3), r=v%1e3, s='';
      if(tr>0) s += (tr===1?'un billion ':sub1000(tr)+' billions ');
      if(b>0) s += (b===1?'un milliard ':sub1000(b)+' milliards ');
      if(m>0) s += (m===1?'un million ':sub1000(m)+' millions ');
      if(k>0) s += (k===1?'mille ':sub1000(k)+' mille ');
      if(r>0) s += sub1000(r);
      return s.trim();
    }
    let res = dec(n); return res.charAt(0).toUpperCase() + res.slice(1);
  }

  function renderCart(p) {
    const list = document.getElementById('list');
    const empty = document.getElementById('empty-cart');
    const countEl = document.getElementById('cart-count');
    
    if(!p.items || p.items.length === 0) {
      list.innerHTML = ''; 
      empty.classList.add('active'); 
      setTotal(0); 
      countEl.innerText = "0";
      return;
    }
    empty.classList.remove('active');
    
    let html = '';
    let totalQty = 0;
    
    p.items.slice().reverse().forEach((it, i) => {
      totalQty += it.qty;
      const img = it.image ? `<img src="/images/\${it.image}" class="item-img">` : `<div class="item-img" style="display:flex;align-items:center;justify-content:center;font-size:16px;color:#aaa;font-weight:700;">\${it.name.charAt(0).toUpperCase()}</div>`;
      html += `
      <div class="item" style="animation-delay:\${i*0.04}s;">
        \${img}
        <div class="item-info">
          <div class="item-name">\${it.name}</div>
          <div class="item-qty-price">\${it.qty} × \${fmt(it.price)}</div>
        </div>
        <div class="item-total">\${fmt(it.total)}</div>
      </div>`;
    });
    
    list.innerHTML = html;
    countEl.innerText = totalQty.toString();
    setTotal(p.total || 0);

    // Marketing logic
    const mkt = document.getElementById('marketing-banner');
    if (p.isGuest && p.potentialPoints > 0) {
      document.getElementById('pot-points').innerText = p.potentialPoints;
      mkt.classList.add('active');
    } else {
      mkt.classList.remove('active');
    }
  }

  function connect() {
    const ws = new WebSocket('ws://$ip:$port/ws?key=$encodedKey');
    const dot = document.getElementById('status-dot');
    ws.onopen = () => { 
      dot.classList.add('online'); 
      window.retryCount = 0;
      console.log('[Danaya+] Display WebSocket connected');
    };
    ws.onmessage = (e) => {
      window.retryCount = 0;
      try {
        const d = JSON.parse(e.data);
        if(d.type === 'play_sound') playSound(d.payload.sound);
        if(d.type === 'cart_updated') {
           renderCart(d.payload);
           if(d.payload.items && d.payload.items.length > 0) playSound('scan_success');
        }
        if(d.type === 'theme_updated') { 
          if(d.payload.theme) applyTheme(d.payload.theme); 
          if(d.payload.shopName) document.getElementById('shop-label').innerText = d.payload.shopName;
          if(d.payload.use3D !== undefined) toggleDanayaFX($use3D && d.payload.use3D);
        }
        if(d.type === 'settings_updated') {
          if(d.payload.theme) applyTheme(d.payload.theme);
          if(d.payload.shopName) document.getElementById('shop-label').innerText = d.payload.shopName;
          if(d.payload.use3D !== undefined) toggleDanayaFX(d.payload.use3D);
          
          // Real-time Ticker Update
          const wrap = document.getElementById('ticker-wrap');
          if(d.payload.enableTicker === false) {
            wrap.style.display = 'none';
          } else if(d.payload.enableTicker === true || (d.payload.messages && d.payload.messages.length > 0)) {
            wrap.style.display = 'flex';
            if(d.payload.messages) {
              const ticker = wrap.querySelector('.ticker');
              ticker.innerHTML = d.payload.messages.map(m => `<div class="ticker-item"><span style="color:#fff;">⚡</span> \${m}</div>`).join('');
            }
          }
        }
        if(d.type === 'sale_completed') {
          playSound('sale_success');
          const c = document.getElementById('celebration');
          document.getElementById('rec-total').innerText = fmt(d.payload.total);
          document.getElementById('rec-paid').innerText = fmt(d.payload.paid);
          document.getElementById('rec-change').innerText = fmt(d.payload.change);
          
          // Loyalty points update
          const pg = d.payload.pointsGained || 0;
          const pr = d.payload.pointsRedeemed || 0;
          const pp = d.payload.potentialPoints || 0;
          const isGuest = d.payload.isGuest || false;
          
          const rowG = document.getElementById('row-points-gained');
          const rowR = document.getElementById('row-points-redeemed');
          const rowM = document.getElementById('row-missing-points');
          
          if(!isGuest && pg > 0) {
            document.getElementById('rec-points-gained').innerText = "+" + pg + " pts";
            rowG.style.display = 'flex';
          } else {
            rowG.style.display = 'none';
          }
          
          if(!isGuest && pr > 0) {
            document.getElementById('rec-points-redeemed').innerText = "-" + pr + " pts";
            rowR.style.display = 'flex';
          } else {
            rowR.style.display = 'none';
          }

          if(isGuest && pp > 0) {
            document.getElementById('rec-missing-points').innerText = pp;
            rowM.style.display = 'block';
          } else {
            rowM.style.display = 'none';
          }
          
          c.style.display='flex'; 
          setTimeout(() => { c.classList.add('active'); c.style.opacity = '1'; }, 10);
          setTimeout(() => { 
            c.style.opacity = '0';
            c.classList.remove('active');
            setTimeout(() => { c.style.display = 'none'; renderCart({items:[]}); }, 400);
          }, 5000);
        }
      } catch(err){}
    };
    ws.onclose = (e) => { 
      dot.classList.remove('online'); 
      if (!window.retryCount) window.retryCount = 0;
      window.retryCount++;
      if (window.retryCount > 4) {
         console.warn('[Danaya+] Trop de pannes réseau, rafraîchissement de la page...');
         setTimeout(() => window.location.reload(), 2000);
      } else {
         setTimeout(connect, 3000); 
      }
    };
  }

  window.onload = () => { 
    applyTheme('$theme'); 
    
    // Check if 3D should be enabled based on dart variable
    if($use3D) {
      setTimeout(() => toggleDanayaFX(true), 500); 
    }
    
    connect(); 
    if(products && products.length > 0) {
      setTimeout(cycleAds, 1000); 
      setInterval(cycleAds, 7000); 
    }
  };
</script>
</body>
</html>
''';
}
