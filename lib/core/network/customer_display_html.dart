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
  bool enableVoice = false,
  bool enableVoiceConfig = false,
  bool enableSounds = true,
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

    /* Floating Merchant Voice Settings Panel */
    .voice-setup-trigger { 
      position: fixed; bottom: 12px; left: 12px; z-index: 9999;
      width: 32px; height: 32px; border-radius: 50%;
      background: rgba(255, 255, 255, 0.15); backdrop-filter: blur(10px);
      border: 1px solid rgba(255, 255, 255, 0.1); color: var(--brand-accent);
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; opacity: 0.3; transition: all 0.3s ease;
    }
    .voice-setup-trigger:hover { opacity: 1; background: rgba(255, 255, 255, 0.25); transform: rotate(45deg); }
    
    .voice-panel {
      position: fixed; bottom: 50px; left: 12px; z-index: 9999;
      width: 340px; background: rgba(15, 23, 42, 0.95); backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 16px;
      padding: 20px; color: #fff; box-shadow: 0 20px 50px rgba(0,0,0,0.5);
      display: none; flex-direction: column; gap: 14px;
      animation: panelFadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    .voice-panel.active { display: flex; }
    
    @keyframes panelFadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    
    .vp-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 10px; margin-bottom: 4px; }
    .vp-title { font-size: 13px; font-weight: 700; color: var(--brand-accent); text-transform: uppercase; letter-spacing: 0.5px; }
    .vp-close { font-size: 18px; cursor: pointer; color: #aaa; transition: color 0.2s; }
    .vp-close:hover { color: #fff; }
    
    .vp-row { display: flex; flex-direction: column; gap: 6px; }
    .vp-label { font-size: 10px; font-weight: 600; color: #aaa; text-transform: uppercase; letter-spacing: 0.5px; }
    
    .vp-select {
      background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.15);
      border-radius: 8px; color: #fff; padding: 8px 12px; font-size: 13px; font-weight: 500;
      outline: none; cursor: pointer; transition: border-color 0.2s; width: 100%;
    }
    .vp-select option { background: #0f172a; color: #fff; }
    .vp-select:focus { border-color: var(--brand-accent); }
    
    .vp-slider-container { display: flex; align-items: center; gap: 12px; }
    .vp-slider { flex: 1; accent-color: var(--brand-accent); cursor: pointer; }
    .vp-val { font-size: 12px; font-weight: 600; color: #fff; width: 35px; text-align: right; }
    
    .vp-btn {
      background: var(--brand-accent); color: #000; border: none; border-radius: 8px;
      padding: 10px; font-size: 13px; font-weight: 700; cursor: pointer;
      display: flex; align-items: center; justify-content: center; gap: 8px;
      transition: all 0.2s ease;
    }
    .vp-btn:hover { background: #fff; transform: translateY(-1px); }
    .vp-btn:active { transform: translateY(0); }
    .vp-btn-secondary {
      background: rgba(255,255,255,0.05); color: #fff; border: 1px solid rgba(255,255,255,0.1);
    }
    .vp-btn-secondary:hover { background: rgba(255,255,255,0.1); }
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
      <div class="mkt-text">Avantage Fidélité : Accumulez des points sur cet achat (<span class="mkt-points" id="pot-points">0</span> points potentiels)<br><span style="font-size: 10px; opacity: 0.7; font-weight: 500;">Inscrivez-vous dès maintenant auprès de notre conseiller.</span></div>
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
      <div class="m-row" id="row-points-gained" style="display: none;"><span style="color: var(--brand-accent); font-weight: 800;">Points Fidélité Crédités</span> <span id="rec-points-gained" style="color: var(--brand-accent); font-weight: 800;">0</span></div>
      <div class="m-row" id="row-points-redeemed" style="display: none;"><span style="color: #ef4444; font-weight: 800;">Réduction Fidélité</span> <span id="rec-points-redeemed" style="color: #ef4444; font-weight: 800;">0</span></div>
      <div id="row-missing-points" style="display: none; margin-top: 10px; padding: 10px; background: rgba(212, 175, 55, 0.1); border-radius: 8px; border: 1px dashed var(--brand-accent);">
         <div style="font-size: 12px; color: var(--text); font-weight: 600;">Adhésion Fidélité : Rejoignez-nous pour cumuler vos <span id="rec-missing-points" style="color: var(--brand-accent); font-weight: 800;">0</span> points.</div>
         <div style="font-size: 10px; color: var(--muted);">Chaque achat vous rapproche de vos avantages exclusifs !</div>
      </div>
      <div class="m-total"><span>Monnaie Rendue</span> <span id="rec-change">0</span></div>
    </div>
  </div>

<script>
  // High-End Themes with DanayaFX Mapping
  const themes = {
    // 1. Quincaillerie & BTP (Effets: GRID, NET, CUBE)
    "theme-q-acier": { bg:"#0f172a", p:"#1e293b", txt:"#f8fafc", a:"#94a3b8", m:"#64748b", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#cbd5e1", s:"Qualité & Robustesse", sub:"Votre partenaire de confiance pour le BTP", q:"Des fondations solides font de grands édifices.", qa:"BÂTISSEUR", eff:"NET" },
    "theme-q-ciment": { bg:"#f8fafc", p:"#ffffff", txt:"#0f172a", a:"#475569", m:"#94a3b8", b:"rgba(0,0,0,0.04)", bt:"#0f172a", ba:"#64748b", s:"Bâtir l'Avenir", sub:"Matériaux durables de haute qualité", q:"L'œuvre résiste quand le matériau est bon.", qa:"PROVERBE", eff:"CUBE" },
    "theme-q-brique": { bg:"#450a0a", p:"#7f1d1d", txt:"#fff5f5", a:"#fca5a5", m:"#f87171", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#ef4444", s:"Solidité & Confiance", sub:"Des fondations pour tous vos chantiers", q:"Chaque brique compte dans le grand mur du succès.", qa:"ARTISAN", eff:"CUBE" },
    "theme-q-bois": { bg:"#1c0d02", p:"#451a03", txt:"#fffbeb", a:"#fbbf24", m:"#d97706", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#f59e0b", s:"Menuiserie de Précision", sub:"L'excellence du bois pour vos aménagements", q:"Le bon bois ne pousse pas dans la facilité.", qa:"FORESTIER", eff:"NET" },
    "theme-q-fer": { bg:"#030712", p:"#111827", txt:"#e5e7eb", a:"#ef4444", m:"#9ca3af", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#dc2626", s:"Métallurgie & Force", sub:"La durabilité au service de vos ouvrages", q:"C'est en forgeant qu'on devient forgeron.", qa:"PROVERBE", eff:"GRID" },
    "theme-q-outil": { bg:"#020617", p:"#0f172a", txt:"#f8fafc", a:"#eab308", m:"#cbd5e1", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#facc15", s:"Outils Professionnels", sub:"La précision pour vos travaux au quotidien", q:"Le bon outil fait la moitié du travail.", qa:"PRO", eff:"NET" },
    "theme-q-chantier": { bg:"#fffbeb", p:"#ffffff", txt:"#1e293b", a:"#d97706", m:"#94a3b8", b:"rgba(0,0,0,0.05)", bt:"#1e293b", ba:"#b45309", s:"Sécurité & Réussite", sub:"L'engagement qualité sur tous vos chantiers", q:"La sécurité est la première étape de toute construction.", qa:"INGÉNIEUR", eff:"GRID" },
    "theme-faso": { bg:"#022c22", p:"#064e3b", txt:"#f0fdf4", a:"#facc15", m:"#f87171", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fef08a", s:"Bâtisseur National", sub:"Soutenir le développement et la croissance", q:"C’est ensemble qu’on construit la nation.", qa:"FASO", eff:"GRID" },
    "theme-q-alu": { bg:"#f1f5f9", p:"#ffffff", txt:"#0f172a", a:"#2563eb", m:"#64748b", b:"rgba(0,0,0,0.05)", bt:"#0f172a", ba:"#3b82f6", s:"Clarté & Modernité", sub:"Menuiserie aluminium et vitrages de prestige", q:"La lumière donne vie à l'architecture.", qa:"DESIGNER", eff:"NET" },
    "theme-q-cuivre": { bg:"#1e1b4b", p:"#312e81", txt:"#faf5ff", a:"#f59e0b", m:"#a5b4fc", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fbbf24", s:"Énergie & Plomberie", sub:"Composants certifiés de haute performance", q:"L'énergie circule là où la qualité est présente.", qa:"INDUSTRY", eff:"GRID" },

    // 2. Prêt-à-porter & Mode (Effets: DUST, AURA, FLOW)
    "theme-bazin": { bg:"#030712", p:"#111827", txt:"#f9fafb", a:"#a3b1c6", m:"#9ca3af", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#778da9", s:"Élégance & Prestige", sub:"Créations de haute couture et textiles fins", q:"L'habit ne fait pas le moine, mais il impose le respect.", qa:"PROVERBE MALIEN", eff:"DUST" },
    "theme-kita": { bg:"#fafaf9", p:"#ffffff", txt:"#44403c", a:"#854d0e", m:"#a8a29e", b:"rgba(0,0,0,0.04)", bt:"#44403c", ba:"#a21caf", s:"Douceur & Tradition", sub:"Tissages authentiques et de qualité supérieure", q:"Le fil ne casse pas s'il est bien tissé.", qa:"TRADITION", eff:"FLOW" },
    "theme-p-soie": { bg:"#fdf2f8", p:"#ffffff", txt:"#831843", a:"#ec4899", m:"#f472b6", b:"rgba(0,0,0,0.04)", bt:"#831843", ba:"#db2777", s:"Raffinement Unique", sub:"Soieries d'exception pour vos créations", q:"L'élégance is la seule beauté qui ne se fane jamais.", qa:"MODE", eff:"DUST" },
    "theme-p-wax": { bg:"#064e3b", p:"#14532d", txt:"#f0fdf4", a:"#facc15", m:"#eab308", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#fef08a", s:"Harmonie & Couleurs", sub:"Collections de wax authentiques et tendances", q:"La couleur est la joie de l'esprit.", qa:"ARTISTE", eff:"DUST" },
    "theme-p-indigo": { bg:"#0f172a", p:"#1e293b", txt:"#eff6ff", a:"#3b82f6", m:"#94a3b8", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#60a5fa", s:"Style & Denim", sub:"Prêt-à-porter moderne et casual chic", q:"Le style est une manière de dire qui vous êtes sans parler.", qa:"STYLISME", eff:"AURA" },
    "theme-p-cuir": { bg:"#18181b", p:"#27272a", txt:"#fafafa", a:"#a1a1aa", m:"#71717a", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#d4d4d8", s:"Maroquinerie d'Exception", sub:"Chaussures et accessoires en cuir véritable", q:"Le bon cuir s'embellit avec le temps.", qa:"ARTISAN", eff:"AURA" },
    "theme-p-dentelle": { bg:"#faf5ff", p:"#ffffff", txt:"#4c1d95", a:"#a855f7", m:"#c084fc", b:"rgba(0,0,0,0.04)", bt:"#4c1d95", ba:"#9333ea", s:"Détails de Charme", sub:"Boutique de prêt-à-porter féminin sélect", q:"Le detail fait la perfection, et la perfection n'est pas un detail.", qa:"VINCI", eff:"DUST" },
    "theme-p-urbain": { bg:"#000000", p:"#0a0a0a", txt:"#ffffff", a:"#10b981", m:"#737373", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#34d399", s:"Mode Contemporaine", sub:"Le style urbain adapté à vos envies", q:"La rue dicte ses propres codes.", qa:"URBAN", eff:"AURA" },
    "theme-p-tailleur": { bg:"#0f172a", p:"#1e293b", txt:"#f8fafc", a:"#94a3b8", m:"#64748b", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#cbd5e1", s:"Sur-Mesure Élite", sub:"Création de costumes et tailleurs de prestige", q:"Un costume bien coupé est une armure moderne.", qa:"KINGSMAN", eff:"AURA" },
    "theme-p-accessoire": { bg:"#fffde6", p:"#ffffff", txt:"#713f12", a:"#eab308", m:"#ca8a04", b:"rgba(0,0,0,0.04)", bt:"#713f12", ba:"#d97706", s:"L'Éclat du Détail", sub:"Bijouterie et accessoires haut de gamme", q:"Les accessoires sont le point d'exclamation d'une tenue.", qa:"KORS", eff:"DUST" },

    // 3. Supermarché & Alimentation (Effets: WAVE, BUBBLES, DNA)
    "theme-sugu": { bg:"#450a0a", p:"#7f1d1d", txt:"#fff5f5", a:"#f97316", m:"#f87171", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fb923c", s:"Votre Grand Marché", sub:"Une sélection complète pour toute la famille", q:"Le marché est le cœur du monde.", qa:"SUGU", eff:"WAVE" },
    "theme-s-frais": { bg:"#f0fdf4", p:"#ffffff", txt:"#14532d", a:"#22c55e", m:"#4ade80", b:"rgba(0,0,0,0.04)", bt:"#14532d", ba:"#16a34a", s:"Fraîcheur Absolue", sub:"Fruits et légumes sélectionnés chaque matin", q:"La santé commence dans l'assiette.", qa:"NUTRITION", eff:"BUBBLES" },
    "theme-s-epice": { bg:"#fff7ed", p:"#ffffff", txt:"#9a3412", a:"#ea580c", m:"#f97316", b:"rgba(0,0,0,0.04)", bt:"#9a3412", ba:"#c2410c", s:"Saveurs & Parfums", sub:"Spécialités culinaires et condiments d'exception", q:"Une bonne épice réveille les souvenirs.", qa:"CHEF", eff:"WAVE" },
    "theme-s-fruit": { bg:"#fdf4ff", p:"#ffffff", txt:"#701a75", a:"#d946ef", m:"#c026d3", b:"rgba(0,0,0,0.04)", bt:"#701a75", ba:"#a21caf", s:"Verger & Nature", sub:"Fruits frais et vitaminés de saison", q:"Le fruit mûr tombe de lui-même.", qa:"PROVERBE", eff:"BUBBLES" },
    "theme-s-boulanger": { bg:"#fffbeb", p:"#ffffff", txt:"#78350f", a:"#d97706", m:"#b45309", b:"rgba(0,0,0,0.04)", bt:"#78350f", ba:"#b45309", s:"Fournil & Tradition", sub:"Pains artisanaux et viennoiseries chaudes", q:"Rien ne vaut l'odeur du pain chaud le matin.", qa:"ARTISAN", eff:"WAVE" },
    "theme-s-viande": { bg:"#4c0519", p:"#831843", txt:"#fff1f2", a:"#fb7185", m:"#e11d48", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#fda4af", s:"Boucherie Premium", sub:"Viandes et charcuteries de qualité rigoureuse", q:"La bonne viande fait le bon repas.", qa:"TERROIR", eff:"WAVE" },
    "theme-s-lait": { bg:"#f8fafc", p:"#ffffff", txt:"#1e293b", a:"#0284c7", m:"#7dd3fc", b:"rgba(0,0,0,0.04)", bt:"#0f172a", ba:"#38bdf8", s:"Crèmerie Pure", sub:"Produits laitiers et fromages d'ici", q:"La pureté est la marque de la nature.", qa:"NATURE", eff:"BUBBLES" },
    "theme-garabal": { bg:"#27160c", p:"#451a03", txt:"#fef3c7", a:"#fbbf24", m:"#b45309", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#f59e0b", s:"Agroalimentaire Pro", sub:"Filières locales et d'élevage de confiance", q:"La terre est le vrai trésor de l’homme.", qa:"GARABAL", eff:"WAVE" },
    "theme-s-bio": { bg:"#022c22", p:"#064e3b", txt:"#ecfdf5", a:"#10b981", m:"#34d399", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#059669", s:"Alimentation Saine", sub:"Produits certifiés bio et respectueux de la nature", q:"La nature ne se presse pas, pourtant tout est accompli.", qa:"LAO TZU", eff:"DNA" },
    "theme-s-gourmet": { bg:"#0a0a0a", p:"#171717", txt:"#f5f5f5", a:"#fbbf24", m:"#a3a3a3", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fbbf24", s:"Épicerie Fine", sub:"Produits d'Exception", q:"Le bon goût est le don de la sélection.", qa:"GOURMET", eff:"BUBBLES" },

    // 4. Beauté & Cosmétique (Effets: DUST, AURA, DNA, FLOW)
    "theme-karite": { bg:"#142417", p:"#2a4d33", txt:"#f5faeb", a:"#a3b18a", m:"#dad7cd", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#c1ccb1", s:"Soin & Bien-être", sub:"Ressources naturelles pour le confort de votre peau", q:"L'arbre de la patience a des fruits très doux.", qa:"PROVERBE MALIEN", eff:"DNA" },
    "theme-b-parfum": { bg:"#1e0b36", p:"#2e1065", txt:"#f3e8ff", a:"#c084fc", m:"#d8b4fe", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#e9d5ff", s:"Fragrances Uniques", sub:"Sélection de parfums et essences rares", q:"Le parfum est la forme la plus intense du souvenir.", qa:"GUERLAIN", eff:"DUST" },
    "theme-b-argan": { bg:"#2d1102", p:"#451a03", txt:"#fef3c7", a:"#fbbf24", m:"#f59e0b", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#fbbf24", s:"Huiles & Soins", sub:"Sérums et cosmétiques naturels haute efficacité", q:"Prenez soin de votre corps, c'est le seul endroit où vous devez vivre.", qa:"ROHN", eff:"DUST" },
    "theme-b-goudron": { bg:"#09090b", p:"#18181b", txt:"#fafafa", a:"#e4e4e7", m:"#71717a", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#a1a1aa", s:"Tradition & Pureté", sub:"Encens et soins traditionnels authentiques", q:"Le bon parfum purifie l'âme.", qa:"SAGESSE", eff:"DUST" },
    "theme-rose": { bg:"#27020d", p:"#4c0519", txt:"#fff1f2", a:"#f43f5e", m:"#fda4af", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fb7185", s:"Éclat & Douceur", sub:"Boutique beauté et cosmétiques de prestige", q:"La courtoisie est la clef d'un service d'exception.", qa:"PROVERBE", eff:"FLOW" },
    "theme-b-nude": { bg:"#fdfaf8", p:"#ffffff", txt:"#431407", a:"#f97316", m:"#fdba74", b:"rgba(0,0,0,0.04)", bt:"#431407", ba:"#fb923c", s:"Teint Parfait", sub:"Maquillages et rituels de beauté au quotidien", q:"La beauté commence au moment où vous décidez d'être vous-même.", qa:"CHANEL", eff:"AURA" },
    "theme-b-or": { bg:"#0c0a09", p:"#1c1917", txt:"#fafaf9", a:"#fbbf24", m:"#a8a29e", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#fcd34d", s:"Beauté de Luxe", sub:"Formules précieuses pour soins haut de gamme", q:"Tout ce qui brille n'est pas d'or, mais vous, oui.", qa:"BEAUTY", eff:"DUST" },
    "theme-b-spa": { bg:"#f0fdfa", p:"#ffffff", txt:"#134e4a", a:"#0d9488", m:"#5eead4", b:"rgba(0,0,0,0.04)", bt:"#134e4a", ba:"#14b8a6", s:"Détente & Harmonie", sub:"Votre espace spa et relaxation professionnelle", q:"Le repos n'est pas une perte de temps.", qa:"SPA", eff:"AURA" },
    "theme-b-onglerie": { bg:"#fdf2f8", p:"#ffffff", txt:"#831843", a:"#db2777", m:"#f9a8d4", b:"rgba(0,0,0,0.04)", bt:"#831843", ba:"#f472b6", s:"Esthétique Parfaite", sub:"Soins des mains et nail art de prestige", q:"La perfection jusqu'au bout des doigts.", qa:"ESTHÉTIQUE", eff:"AURA" },
    "theme-b-cheveux": { bg:"#020617", p:"#0f172a", txt:"#f8fafc", a:"#0ea5e9", m:"#7dd3fc", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#38bdf8", s:"Coiffure Design", sub:"Créateurs de style et soins capillaires avancés", q:"Une belle coiffure est la meilleure couronne.", qa:"COIFFURE", eff:"DUST" },

    // 5. High-Tech & Électronique (Effets: MATRIX, GRID, NET, SATURN, CUBE)
    "theme-neon": { bg:"#020617", p:"#0f172a", txt:"#f8fafc", a:"#38bdf8", m:"#94a3b8", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#38bdf8", s:"L'Innovation Connectée", sub:"Produits high-tech et solutions intelligentes", q:"Innover, c’est créer le monde de demain.", qa:"JOBS", eff:"SATURN" },
    "theme-cyberpunk": { bg:"#180006", p:"#3f000f", txt:"#ffe4e6", a:"#fb7185", m:"#be123c", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#e11d48", s:"Performance & Puissance", sub:"Équipements informatiques de pointe", q:"La technologie est la magie de notre époque.", qa:"STEVE", eff:"GRID" },
    "theme-midnight": { bg:"#000000", p:"#09090b", txt:"#fafafa", a:"#d8b4fe", m:"#a1a1aa", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#a855f7", s:"Haute Résolution", sub:"Écrans et accessoires visuels premium", q:"L'image parfaite nécessite un contraste absolu.", qa:"TECH", eff:"SATURN" },
    "theme-h-silicon": { bg:"#020617", p:"#0f172a", txt:"#f8fafc", a:"#10b981", m:"#6ee7b7", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#34d399", s:"Solutions Informatiques", sub:"Ordinateurs et composants professionnels", q:"L'informatique est le vélo de l'esprit.", qa:"JOBS", eff:"CUBE" },
    "theme-h-fibre": { bg:"#031c30", p:"#082f49", txt:"#f0f9ff", a:"#38bdf8", m:"#bae6fd", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#7dd3fc", s:"Fibre & Connectivité", sub:"Réseaux haut débit et télécoms d'avenir", q:"Être connecté, c'est exister.", qa:"NETWORK", eff:"NET" },
    "theme-h-gaming": { bg:"#0a0a0a", p:"#171717", txt:"#fafafa", a:"#ef4444", m:"#f87171", b:"rgba(255,255,255,0.08)", bt:"#ffffff", ba:"#dc2626", s:"Setup Haute Performance", sub:"Accessoires de jeu et ordinateurs puissants", q:"Ne jamais abandonner la partie.", qa:"GAMER", eff:"GRID" },
    "theme-h-mobile": { bg:"#f8fafc", p:"#ffffff", txt:"#0f172a", a:"#2563eb", m:"#64748b", b:"rgba(0,0,0,0.04)", bt:"#0f172a", ba:"#3b82f6", s:"Solutions Mobiles", sub:"Smartphones et tablettes de dernière génération", q:"Le monde entier dans votre poche.", qa:"MOBILE", eff:"MATRIX" },
    "theme-h-photo": { bg:"#0c0a09", p:"#1c1917", txt:"#fafaf9", a:"#fbbf24", m:"#a8a29e", b:"rgba(255,255,255,0.05)", bt:"#ffffff", ba:"#facc15", s:"Objectif & Image", sub:"Caméras, optiques et drones professionnels", q:"Capturer l'instant pour l'éternité.", qa:"PHOTOGRAPHE", eff:"NET" },
    "theme-h-audio": { bg:"#1e1b4b", p:"#312e81", txt:"#e0e7ff", a:"#818cf8", m:"#a5b4fc", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#c7d2fe", s:"Acoustique Pure", sub:"Systèmes de son et casques audiophiles", q:"La musique donne une âme à nos cœurs.", qa:"PLATON", eff:"GRID" },
    "theme-h-smart": { bg:"#f0fdfa", p:"#ffffff", txt:"#0f172a", a:"#14b8a6", m:"#5eead4", b:"rgba(0,0,0,0.04)", bt:"#0f172a", ba:"#0d9488", s:"Maison Connectée", sub:"Solutions domotiques et sécurité résidentielle", q:"La maison intelligente anticipe vos besoins.", qa:"SMART", eff:"MATRIX" },

    // 6. Corporate & Prestige (Effets: CASH, NET, AURA, SATURN)
    "theme-luxury": { bg:"#050505", p:"#121214", txt:"#fafafa", a:"#D4AF37", m:"#a1a1aa", b:"rgba(212,175,55,0.18)", bt:"#ffffff", ba:"#D4AF37", s:"Service d'Exception", sub:"L'excellence et la distinction au quotidien", q:"Le raffinement est la forme ultime de l’élégance.", qa:"ANONYME", eff:"CASH" },
    "theme-corporate": { bg:"#030712", p:"#111827", txt:"#f9fafb", a:"#3b82f6", m:"#9ca3af", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#60a5fa", s:"À Votre Service", sub:"Votre partenaire de confiance au quotidien", q:"La qualité n’est pas un acte, c’est une habitude.", qa:"ARISTOTE", eff:"NET" },
    "theme-wallstreet": { bg:"#020617", p:"#0f172a", txt:"#f1f5f9", a:"#3b82f6", m:"#94a3b8", b:"rgba(59,130,246,0.18)", bt:"#ffffff", ba:"#60a5fa", s:"Ambition & Croissance", sub:"Solutions d'affaires performantes et d'avenir", q:"Le temps, c’est de l’argent.", qa:"FRANKLIN", eff:"CASH" },
    "theme-monaco": { bg:"#27020d", p:"#4c0519", txt:"#fff1f2", a:"#fb7185", m:"#fda4af", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#f43f5e", s:"Raffinement Signature", sub:"L'élégance intemporelle pour vos choix", q:"La grâce est plus belle encore que la beauté.", qa:"LA FONTAINE", eff:"FLOW" },
    "theme-empire": { bg:"#270509", p:"#4a0e17", txt:"#fcf3d9", a:"#f5d061", m:"#b59535", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#d4af37", s:"Excellence Durable", sub:"Votre réussite est notre plus grand engagement", q:"La patience est la clé de la richesse.", qa:"SAGESSE", eff:"CASH" },
    "theme-dakan": { bg:"#1e0b36", p:"#2e1065", txt:"#f5f3ff", a:"#d8b4fe", m:"#8b5cf6", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#c084fc", s:"Votre Réussite", sub:"Construire ensemble votre projet de demain", q:"Le succès est au bout de l’effort.", qa:"DAKAN", eff:"SATURN" },
    "theme-wariba": { bg:"#271203", p:"#422006", txt:"#fef3c7", a:"#fbbf24", m:"#d97706", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#f59e0b", s:"Valeur & Sécurité", sub:"Des solutions performantes pour votre sérénité", q:"L’argent ne fait pas de bruit, mais il construit.", qa:"WARI", eff:"CASH" },
    "theme-jago": { bg:"#020617", p:"#0f172a", txt:"#f8fafc", a:"#94a3b8", m:"#64748b", b:"rgba(255,255,255,0.06)", bt:"#ffffff", ba:"#cbd5e1", s:"Relations de Confiance", sub:"Le sérieux professionnel pour vos transactions", q:"Les bonnes affaires se font dans la confiance.", qa:"JAGO", eff:"NET" },
    "theme-obsidian": { bg:"#020205", p:"#0d0d11", txt:"#f9fafb", a:"#f3f4f6", m:"#9ca3af", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#e5e7eb", s:"Discrétion & Rigueur", sub:"L'expertise haut de gamme en toute confiance", q:"Le silence est l’écrin de la richesse.", qa:"ANONYME", eff:"CASH" },
    "theme-sanife": { bg:"#041e2b", p:"#083344", txt:"#ecfeff", a:"#67e8f9", m:"#06b6d4", b:"rgba(255,255,255,0.07)", bt:"#ffffff", ba:"#22d3ee", s:"L'Art du Détail", sub:"Le soin et la qualité dans chaque prestation", q:"Ce qui a de la valeur mérite d’être soigné.", qa:"SANI", eff:"CASH" },
    "theme-ocean-flame": { bg:"#090500", p:"#1c0c02", txt:"#fafaf9", a:"#ea580c", m:"#a8a29e", b:"rgba(234,88,12,0.15)", bt:"#ffffff", ba:"#fbbf24", s:"Excellence & Confiance", sub:"Notre engagement absolu pour votre entière satisfaction", q:"Votre confiance inspire notre recherche constante de l'excellence.", qa:"ENGAGEMENT", eff:"FLAME" },
    "theme-abyss-fire": { bg:"#000000", p:"#0d0400", txt:"#faf5f5", a:"#dc2626", m:"#f87171", b:"rgba(220,38,38,0.18)", bt:"#ffffff", ba:"#f43f5e", s:"L'Art du Service", sub:"Chaque client est unique, chaque détail compte", q:"Chaque interaction est une opportunité de dépasser vos attentes.", qa:"SERVICE", eff:"FLAME" },
    "theme-cosmic-magma": { bg:"#05000a", p:"#140226", txt:"#fdfaff", a:"#c084fc", m:"#d8b4fe", b:"rgba(192,132,252,0.15)", bt:"#ffffff", ba:"#fb7185", s:"Prestige Signature", sub:"La référence de qualité pour vos exigences", q:"Concevoir des solutions d'exception pour accompagner votre succès.", qa:"PRESTIGE", eff:"FLAME" }
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
    
    const sloganEl = document.getElementById('slogan-1');
    if (sloganEl) sloganEl.innerHTML = t.s.replace(' & ', '<br>& ');
    
    const sloganSubEl = document.querySelector('.slogan-sub');
    if (sloganSubEl) sloganSubEl.innerText = t.sub;

    // Fast Quote Update
    const qText = document.getElementById('quote-text');
    const qAuthor = document.getElementById('quote-author');
    const qArea = document.getElementById('quote-area');
    if (qText) qText.innerText = t.q;
    if (qAuthor) qAuthor.innerText = t.qa;
    if (qArea) qArea.style.opacity = '1';
    
    // Launch Offline FX Engine only if enabled
    if (window._use3DEnabled) {
      toggleDanayaFX(true);
    } else {
      toggleDanayaFX(false);
    }
  }

  // --- DANAYAFX UNIFIED MULTI-MODE 3D OFFLINE ENGINE (0 CND, 0 BOGUE) ---
  class DanayaFXEngine {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.color = {r: 255, g: 255, b: 255};
      this.colorHex = '#ffffff';
      this.isActive = false;
      this.mode = 'NET'; // NET, AURA, DUST, MATRIX, WAVE, GRID, CASH, BUBBLES, VORTEX, DNA, SPHERE, FLOW
      
      // Multi-mode variables
      this.elements = [];
      this.gridOffset = 0;
      this.matrixColumns = [];
      
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
      this.initModeData();
    }

    initModeData() {
      this.elements = [];
      const w = this.canvas.width;
      const h = this.canvas.height;
      const tId = window._currentTheme || 'theme-luxury';

      if (this.mode === 'NET') {
        // 3D Constellation Neural Grid Init
        let num = Math.min(Math.floor((w * h) / 7500), 120);
        if (tId === 'theme-h-fibre') num = 160;
        if (tId === 'theme-jago') num = 50;
        
        for(let i=0; i<num; i++) {
          this.elements.push({
            x3d: (Math.random() - 0.5) * w * 0.9,
            y3d: (Math.random() - 0.5) * h * 0.9,
            z3d: (Math.random() - 0.5) * 2.0, // Depth axis
            vx3d: (Math.random() - 0.5) * 1.5,
            vy3d: (Math.random() - 0.5) * 1.5,
            vz3d: (Math.random() - 0.5) * 0.015,
            radius: Math.random() * 2.5 + 1.5
          });
        }
      } 
      else if (this.mode === 'DUST') {
        // 3D Warp Starfield Nebula Init
        let num = Math.min(Math.floor((w * h) / 4500), 180);
        if (tId === 'theme-b-or') num = 240;
        if (tId === 'theme-p-dentelle') num = 70;
        
        for(let i=0; i<num; i++) {
          this.elements.push({
            x3d: (Math.random() - 0.5) * w * 2.0,
            y3d: (Math.random() - 0.5) * h * 2.0,
            z3d: Math.random() * 4.0 + 0.1, // Depth axis
            radius: Math.random() * 2.2 + 0.8,
            colorScale: Math.random() * 0.35 + 0.65
          });
        }
      }
      else if (this.mode === 'BUBBLES') {
        // 3D Liquid Spheres / Organic Glossy Metaballs Init
        let num = Math.min(Math.floor((w * h) / 9000), 50);
        if (tId === 'theme-s-gourmet') num = 90;
        
        for(let i=0; i<num; i++) {
          this.elements.push({
            x3d: (Math.random() - 0.5) * w * 0.8,
            y3d: h/2 + Math.random() * 150,
            z3d: Math.random() * 2.0 + 0.5,
            vy3d: -Math.random() * 2.0 - 1.0,
            wobbleSpeed: Math.random() * 0.04 + 0.01,
            wobbleAmount: Math.random() * 6 + 2,
            radius: Math.random() * 10 + 4
          });
        }
      }
      else if (this.mode === 'MATRIX') {
        // 3D Cyber Grid Matrix rain Init
        const fontSize = 14;
        const columns = Math.floor(w / fontSize) + 1;
        this.matrixColumns = [];
        for (let i = 0; i < columns; i++) {
          this.matrixColumns.push({
            x: i * fontSize,
            y: Math.random() * -150 - 30,
            z3d: Math.random() * 2.5 + 0.5, // Perspective depth
            speed: Math.random() * 2.8 + 1.2,
            chars: []
          });
        }
      }
      else if (this.mode === 'CASH') {
        // 3D Spinning Coins & Cash cascade Init
        let symbols = ['F', 'CFA', '★', '♦', '♣', '♥', '💰'];
        if (tId === 'theme-luxury') symbols = ['★', '♦', '💎', '👑'];
        if (tId === 'theme-wallstreet') symbols = ['\$', '€', '▲', '▼', '📈', '💹'];
        if (tId === 'theme-empire') symbols = ['👑', '★', 'Imperial', '⚜️'];
        if (tId === 'theme-wariba') symbols = ['💰', '💵', 'CFA', 'F'];
        if (tId === 'theme-obsidian') symbols = ['♠️', '♦', '♣', '♥', '💎'];
        if (tId === 'theme-sanife') symbols = ['💎', '✨', '💍', '💙'];
        
        const num = Math.min(Math.floor((w * h) / 12000), 35);
        for(let i=0; i<num; i++) {
          this.elements.push({
            x3d: (Math.random() - 0.5) * w * 1.1,
            y3d: -h/2 - Math.random() * 200,
            z3d: Math.random() * 2.0 + 0.5,
            vy3d: Math.random() * 2.2 + 1.2,
            rotX: Math.random() * Math.PI * 2,
            rotY: Math.random() * Math.PI * 2,
            rotZ: Math.random() * Math.PI * 2,
            rotSpeedX: (Math.random() - 0.5) * 0.04,
            rotSpeedY: (Math.random() - 0.5) * 0.04,
            rotSpeedZ: (Math.random() - 0.5) * 0.03,
            size: Math.random() * 16 + 12,
            text: symbols[Math.floor(Math.random() * symbols.length)]
          });
        }
      }
      else if (this.mode === 'GRID') {
        // 3D Retro Outrun Horizon Grid with Flying Obstacles Init
        this.gridOffset = 0;
        this.pillars = [];
        for(let i = 0; i < 6; i++) {
          this.pillars.push({
            side: i % 2 === 0 ? -1 : 1, // Left or Right of road
            z3d: (i / 6) * 4.0 + 0.1,  // Spread depth
            height: Math.random() * 80 + 40,
            width: 25
          });
        }
      }
      else if (this.mode === 'VORTEX') {
        // 3D Space Spiral Wormhole Init
        const num = tId === 'theme-dakan' ? 160 : 120;
        for(let i=0; i<num; i++) {
          this.elements.push({
            angle: Math.random() * Math.PI * 2,
            distance: Math.random() * Math.max(w, h) * 0.8,
            speed: Math.random() * 0.015 + 0.005,
            radius: Math.random() * 2 + 1,
            colorScale: Math.random() * 0.4 + 0.6
          });
        }
      }
      else if (this.mode === 'DNA') {
        // 3D Double Helix Bio Helix Init
        const num = 40;
        for(let i=0; i<num; i++) {
          this.elements.push({
            yPos: i / num,
            phase: (i / num) * Math.PI * 4,
          });
        }
      }
      else if (this.mode === 'SPHERE') {
        // 3D Plasma Hologram Sphere Init
        const num = tId === 'theme-h-photo' ? 70 : 100;
        for(let i=0; i<num; i++) {
          const u = Math.random();
          const v = Math.random();
          const theta = u * 2.0 * Math.PI;
          const phi = Math.acos(2.0 * v - 1.0);
          this.elements.push({
            x3d: Math.sin(phi) * Math.cos(theta),
            y3d: Math.sin(phi) * Math.sin(theta),
            z3d: Math.cos(phi),
            radius: Math.random() * 2 + 1
          });
        }
      }
      else if (this.mode === 'FLOW') {
        // 3D Aurora Flow Ribbons Init
        const num = tId === 'theme-rose' ? 6 : 4;
        for(let i=0; i<num; i++) {
          this.elements.push({
            yBase: h * (0.3 + i * 0.12),
            speed: 0.001 + i * 0.0003,
            amplitude: 40 + i * 15,
            frequency: 0.003 + i * 0.001,
            phaseOffset: i * Math.PI * 0.4,
            thickness: 4 + i * 3
          });
        }
      }
      else if (this.mode === 'CUBE') {
        // 3D Tesseract / Rotating Cube Init
        this.cubeVertices = [
          {x: -1, y: -1, z: -1},
          {x: 1, y: -1, z: -1},
          {x: 1, y: 1, z: -1},
          {x: -1, y: 1, z: -1},
          {x: -1, y: -1, z: 1},
          {x: 1, y: -1, z: 1},
          {x: 1, y: 1, z: 1},
          {x: -1, y: 1, z: 1}
        ];
        this.cubeEdges = [
          [0, 1], [1, 2], [2, 3], [3, 0],
          [4, 5], [5, 6], [6, 7], [7, 4],
          [0, 4], [1, 5], [2, 6], [3, 7]
        ];
      }
      else if (this.mode === 'SATURN') {
        // 🪐 Celestial Saturn & Orbiting Ring particles Init
        const numRingPoints = 160;
        this.saturnRings = [];
        for(let i=0; i<numRingPoints; i++) {
          this.saturnRings.push({
            theta: Math.random() * Math.PI * 2,
            rRing: Math.min(w, h) * 0.18 + Math.random() * (Math.min(w, h) * 0.15),
            speed: Math.random() * 0.004 + 0.002,
            radius: Math.random() * 1.6 + 0.6,
            colorScale: Math.random() * 0.35 + 0.65
          });
        }
      }
      else if (this.mode === 'FLAME') {
        // 🌋 3D Magma / Flaming Ocean with floating ash particles Init
        const numSparks = 60;
        this.elements = [];
        for(let i=0; i<numSparks; i++) {
          this.elements.push({
            x3d: (Math.random() - 0.5) * w * 1.2,
            y3d: h/2 - Math.random() * h * 0.4,
            z3d: Math.random() * 2.0 + 0.5,
            vy3d: -Math.random() * 1.5 - 0.5, // rising sparks
            vx3d: (Math.random() - 0.5) * 1.0,
            wobbleSpeed: Math.random() * 0.05 + 0.02,
            wobbleAmount: Math.random() * 8 + 2,
            radius: Math.random() * 3 + 1,
            colorScale: Math.random() * 0.4 + 0.6
          });
        }
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

    updateTheme(theme) {
      this.colorHex = theme.a;
      this.color = this.hexToRgb(theme.a) || {r:255, g:255, b:255};
      this.mode = theme.eff || 'NET';
      this.initModeData();
    }

    animate() {
      if(!this.isActive) return;
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      
      const w = this.canvas.width;
      const h = this.canvas.height;
      const r = this.color.r;
      const g = this.color.g;
      const b = this.color.b;
      const tId = window._currentTheme || 'theme-luxury';
      const fov = 3.0;
      const cx = w / 2;
      const cy = h / 2;

      // 1. NEURAL CONSTELATION 3D MODE
      if (this.mode === 'NET') {
        const time = Date.now() * 0.0003;
        const cosY = Math.cos(time), sinY = Math.sin(time);
        const projected = [];
        
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          // Movement inside 3D bounds
          p.x3d += p.vx3d; p.y3d += p.vy3d; p.z3d += p.vz3d;
          if(Math.abs(p.x3d) > w*0.5) p.vx3d *= -1;
          if(Math.abs(p.y3d) > h*0.5) p.vy3d *= -1;
          if(Math.abs(p.z3d) > 1.2) p.vz3d *= -1;
          
          // Y axis rotation
          let xRot = p.x3d * cosY - p.z3d * w * 0.2 * sinY;
          let zRot = p.x3d * sinY + p.z3d * w * 0.2 * cosY;
          
          // Projection
          const scale = fov / (fov + zRot / (w * 0.4));
          const px = cx + xRot * scale;
          const py = cy + p.y3d * scale;
          
          const depthAlpha = (1.5 - zRot / (w * 0.4)) / 2.2 * 0.75 + 0.25;
          const nodeRadius = p.radius * scale;
          
          projected.push({x: px, y: py, z: zRot, alpha: depthAlpha, r: nodeRadius});
          
          this.ctx.beginPath();
          if (tId === 'theme-q-alu') {
            this.ctx.rect(px - nodeRadius, py - nodeRadius, nodeRadius*2, nodeRadius*2);
          } else if (tId === 'theme-q-bois') {
            this.ctx.arc(px, py, nodeRadius * 1.4, 0, Math.PI * 2);
          } else {
            this.ctx.arc(px, py, nodeRadius, 0, Math.PI * 2);
          }
          this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + depthAlpha + ')';
          this.ctx.fill();
        }
        
        // Connections in 3D space
        for(let i=0; i<projected.length; i++) {
          const pA = this.elements[i];
          const projA = projected[i];
          for(let j=i+1; j<projected.length; j++) {
            const pB = this.elements[j];
            const projB = projected[j];
            
            // Calculate real 3D distance
            const dist3d = Math.hypot(pA.x3d - pB.x3d, pA.y3d - pB.y3d, (pA.z3d - pB.z3d) * w * 0.2);
            if(dist3d < 140) {
              this.ctx.beginPath();
              this.ctx.moveTo(projA.x, projA.y);
              this.ctx.lineTo(projB.x, projB.y);
              
              const lineAlpha = (1.0 - dist3d/140) * Math.min(projA.alpha, projB.alpha) * 0.45;
              let strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + lineAlpha + ')';
              if (tId === 'theme-q-acier') strokeStyle = 'rgba(148,163,184,' + lineAlpha + ')';
              if (tId === 'theme-q-cuivre') strokeStyle = 'rgba(217,119,6,' + lineAlpha + ')';
              
              this.ctx.strokeStyle = strokeStyle;
              this.ctx.lineWidth = tId === 'theme-q-acier' ? 1.5 : 1.0;
              this.ctx.stroke();
            }
          }
        }
      }
      // 2. 3D WARP STARFIELD NEBULA MODE
      else if (this.mode === 'DUST') {
        const time = Date.now() * 0.0003;
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          p.z3d -= 0.012; // Warp travel speed
          
          if(p.z3d <= 0.1) {
            p.z3d = 4.0;
            p.x3d = (Math.random() - 0.5) * w * 2.0;
            p.y3d = (Math.random() - 0.5) * h * 2.0;
          }
          
          // Rotate slightly around center Z
          const cosZ = Math.cos(0.005), sinZ = Math.sin(0.005);
          const rx = p.x3d * cosZ - p.y3d * sinZ;
          const ry = p.x3d * sinZ + p.y3d * cosZ;
          p.x3d = rx; p.y3d = ry;
          
          // Projection
          const scale = fov / p.z3d;
          const px = cx + p.x3d * scale;
          const py = cy + p.y3d * scale;
          
          const alpha = (4.0 - p.z3d) / 4.0 * 0.85 + 0.15;
          const starSize = p.radius * scale;
          
          // Draw trail (star speed lines)
          const pxPrev = cx + p.x3d * (fov / (p.z3d + 0.1));
          const pyPrev = cy + p.y3d * (fov / (p.z3d + 0.1));
          
          this.ctx.beginPath();
          this.ctx.moveTo(px, py);
          this.ctx.lineTo(pxPrev, pyPrev);
          this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + (alpha * 0.25) + ')';
          this.ctx.lineWidth = starSize * 0.5;
          this.ctx.stroke();
          
          // Draw star node
          this.ctx.beginPath();
          this.ctx.arc(px, py, starSize, 0, Math.PI * 2);
          this.ctx.save();
          this.ctx.shadowBlur = tId === 'theme-b-or' ? 12 : 5;
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
          this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
          this.ctx.fill();
          this.ctx.restore();
        }
      }
      // 3. 3D GLOSSY LIQUID SPHERES MODE
      else if (this.mode === 'BUBBLES') {
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          p.y3d += p.vy3d;
          // Sine wobble horizontal
          const wobble = Math.sin(p.y3d * p.wobbleSpeed) * p.wobbleAmount;
          
          // Reset bottom
          if(p.y3d < -h * 0.6) {
            p.y3d = h * 0.6;
            p.x3d = (Math.random() - 0.5) * w * 0.8;
          }
          
          const scale = fov / (fov + p.z3d);
          const px = cx + (p.x3d + wobble) * scale;
          const py = cy + p.y3d * scale;
          
          const size = p.radius * scale * 2.2;
          const alpha = (3.0 - p.z3d) / 3.0 * 0.72 + 0.18;
          
          // Radial Glossy 3D sphere gradient
          const grad = this.ctx.createRadialGradient(px - size * 0.3, py - size * 0.3, size * 0.05, px, py, size);
          if (tId === 'theme-s-gourmet') {
            grad.addColorStop(0, 'rgba(255, 239, 184, ' + alpha + ')');
            grad.addColorStop(0.8, 'rgba(212, 175, 55, ' + (alpha * 0.45) + ')');
            grad.addColorStop(1, 'rgba(120, 90, 10, 0)');
          } else if (tId === 'theme-s-lait') {
            grad.addColorStop(0, 'rgba(255, 255, 255, ' + alpha + ')');
            grad.addColorStop(0.7, 'rgba(224, 242, 254, ' + (alpha * 0.6) + ')');
            grad.addColorStop(1, 'rgba(56, 189, 248, 0)');
          } else {
            grad.addColorStop(0, 'rgba(255, 255, 255, ' + alpha + ')');
            grad.addColorStop(0.6, 'rgba(' + r + ',' + g + ',' + b + ',' + (alpha * 0.4) + ')');
            grad.addColorStop(1, 'rgba(' + r + ',' + g + ',' + b + ', 0)');
          }
          
          this.ctx.beginPath();
          this.ctx.arc(px, py, size, 0, Math.PI * 2);
          this.ctx.fillStyle = grad;
          this.ctx.fill();
          
          // Subtle high glossy glass bubble borders
          this.ctx.beginPath();
          this.ctx.arc(px, py, size, 0, Math.PI * 2);
          this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + (alpha * 0.35) + ')';
          this.ctx.lineWidth = 1.0;
          this.ctx.stroke();
        }
      }
      // 4. 3D CYBER GRID MATRIX rain MODE
      else if (this.mode === 'MATRIX') {
        const fontSize = 14;
        let chars = "0123456789ABCDEF⚡💻📶🔋💾⚙️🛠️";
        if (tId === 'theme-h-silicon') chars = "01";
        if (tId === 'theme-h-mobile') chars = "📱💬❤️⚙️🔔🔋📶";
        if (tId === 'theme-h-smart') chars = "🏠💡🌡️🔒🚿📺";
        
        for (let i = 0; i < this.matrixColumns.length; i++) {
          const col = this.matrixColumns[i];
          const char = chars[Math.floor(Math.random() * chars.length)];
          
          col.chars.push({ char, y: col.y });
          col.y += col.speed * 3.5;
          
          if (col.y > h + 150 && Math.random() > 0.98) {
            col.y = Math.random() * -150 - 30;
            col.chars = [];
          }
          
          // Depth projection scale
          const scale = fov / (fov + col.z3d);
          const px = cx + (col.x - cx) * scale;
          const alpha = (3.5 - col.z3d) / 3.5 * 0.72 + 0.15;
          const currentFont = Math.floor(fontSize * scale);
          
          this.ctx.font = 'bold ' + currentFont + 'px monospace';
          
          for (let j = 0; j < col.chars.length; j++) {
            const node = col.chars[j];
            const cellAlpha = (j / col.chars.length) * alpha;
            const py = cy + (node.y - cy) * scale;
            
            this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + cellAlpha + ')';
            this.ctx.fillText(node.char, px, py);
          }
          
          if (col.chars.length > 25) col.chars.shift();
        }
      }
      // 5. 3D WAVE ribbon mesh/Nigerian River ocean waves
      else if (this.mode === 'WAVE') {
        const time = Date.now() * 0.0012;
        this.ctx.save();
        
        let waves = 4;
        if (tId === 'theme-s-boulange') waves = 5;
        
        // Loop depths layers from back to front
        for(let j=waves; j>0; j--) {
          this.ctx.beginPath();
          const zDepth = j * 0.45;
          const scale = fov / (fov + zDepth);
          
          let fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + ((0.12 - j * 0.02) * scale) + ')';
          if (tId === 'theme-s-epices') {
            fillStyle = j % 2 === 0 ? 'rgba(217,119,6,0.06)' : 'rgba(180,83,9,0.04)';
          }
          
          this.ctx.fillStyle = fillStyle;
          
          for(let x=0; x<=w; x += 15) {
            let amp = (30 + j * 15) * scale;
            let freq = 0.005 + j * 0.0005;
            if (tId === 'theme-s-boulange') { amp = 20 * scale; freq = 0.007; }
            
            const localY = h * 0.65 + Math.sin(x * freq + time + j) * amp + Math.cos(x * 0.002 - time * 0.4) * (amp * 0.35);
            const px = cx + (x - cx) * scale;
            const py = cy + (localY - cy) * scale;
            
            if (x === 0) this.ctx.moveTo(px, py);
            else this.ctx.lineTo(px, py);
          }
          
          // Connect to bottom center horizon
          this.ctx.lineTo(w, h);
          this.ctx.lineTo(0, h);
          this.ctx.closePath();
          this.ctx.fill();
        }
        this.ctx.restore();
      }
      // 6. PERSPECTIVE GRID SOL + FLYING 3D NEON PILLARS
      else if (this.mode === 'GRID') {
        this.gridOffset += 2.0;
        if(this.gridOffset >= 60) this.gridOffset = 0;
        
        this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ', 0.12)';
        this.ctx.lineWidth = 1.5;
        
        if (tId === 'theme-cyberpunk') {
          this.ctx.strokeStyle = 'rgba(225, 29, 72, 0.28)';
          const grad = this.ctx.createRadialGradient(cx, h*0.35, 10, cx, h*0.35, Math.min(w, h)*0.3);
          grad.addColorStop(0, 'rgba(225, 29, 72, 0.15)');
          grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
          this.ctx.fillStyle = grad;
          this.ctx.beginPath();
          this.ctx.arc(cx, h*0.35, Math.min(w, h)*0.3, 0, Math.PI*2);
          this.ctx.fill();
        }
        
        const horizon = h * 0.45;
        const spacing = 60;
        const numBeams = 24;
        
        for(let i=0; i<=numBeams; i++) {
          const xStart = (w / numBeams) * i;
          this.ctx.beginPath();
          this.ctx.moveTo(xStart, horizon);
          const xEnd = cx + (xStart - cx) * 3.8;
          this.ctx.lineTo(xEnd, h);
          this.ctx.stroke();
        }
        
        for (let y = horizon + this.gridOffset; y < h; y += spacing) {
          const ratio = (y - horizon) / (h - horizon);
          const scaleY = horizon + Math.pow(ratio, 2.2) * (h - horizon);
          this.ctx.beginPath();
          this.ctx.moveTo(0, scaleY);
          this.ctx.lineTo(w, scaleY);
          this.ctx.stroke();
        }
        
        // Render flying 3D pillars on sides of grid!
        for(let i=0; i<this.pillars.length; i++) {
          const pil = this.pillars[i];
          pil.z3d -= 0.015; // Move towards screen
          if(pil.z3d <= 0.15) {
            pil.z3d = 4.0;
            pil.height = Math.random() * 80 + 40;
          }
          
          const scale = fov / pil.z3d;
          const roadOffset = w * 0.22 * pil.side;
          const px = cx + roadOffset * scale;
          const py = horizon + (h - horizon) * scale * 0.4;
          
          const pHeight = pil.height * scale;
          const pWidth = pil.width * scale;
          const alpha = (4.0 - pil.z3d) / 4.0 * 0.85 + 0.1;
          
          // Draw a glowing neon rectangular pillar
          this.ctx.save();
          this.ctx.beginPath();
          this.ctx.rect(px - pWidth/2, py - pHeight, pWidth, pHeight);
          
          const grad = this.ctx.createLinearGradient(px, py - pHeight, px, py);
          grad.addColorStop(0, 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')');
          grad.addColorStop(1, 'rgba(' + r + ',' + g + ',' + b + ', 0.05)');
          
          this.ctx.fillStyle = grad;
          this.ctx.shadowBlur = 10 * scale;
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
          this.ctx.fill();
          this.ctx.restore();
        }
      }
      // 7. 3D SPINNING GOLD COINS & DOLLAR CASCADE
      else if (this.mode === 'CASH') {
        const time = Date.now() * 0.001;
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          // Physics
          p.y3d += p.vy3d;
          p.rotX += p.rotSpeedX;
          p.rotY += p.rotSpeedY;
          p.rotZ += p.rotSpeedZ;
          
          if(p.y3d > h * 0.6) {
            p.y3d = -h * 0.6 - Math.random() * 150;
            p.x3d = (Math.random() - 0.5) * w * 1.1;
          }
          
          const scale = fov / (fov + p.z3d);
          const px = cx + p.x3d * scale;
          const py = cy + p.y3d * scale;
          
          const alpha = (2.5 - p.z3d) / 2.5 * 0.72 + 0.18;
          const coinSize = p.size * scale;
          
          this.ctx.save();
          this.ctx.translate(px, py);
          
          // Apply 3D matrix rotations via 2D transforms (tilt look)
          const scaleX = Math.cos(p.rotX);
          const scaleY = Math.cos(p.rotY);
          this.ctx.scale(scaleX, scaleY);
          this.ctx.rotate(p.rotZ);
          
          this.ctx.font = "bold " + coinSize + "px sans-serif";
          
          let fillStyle = 'rgba(' + r + ',' + g + ',' + b + ', ' + alpha + ')';
          if (tId === 'theme-luxury') fillStyle = 'rgba(212, 175, 55, ' + alpha + ')';
          if (tId === 'theme-empire') fillStyle = 'rgba(245, 208, 97, ' + alpha + ')';
          
          this.ctx.fillStyle = fillStyle;
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ', 0.5)';
          this.ctx.shadowBlur = 6 * scale;
          this.ctx.fillText(p.text, -coinSize/2, coinSize/2);
          
          this.ctx.restore();
        }
      }
      // 8. COSMIC VORTEX TUNNEL (Futuristic space effect)
      else if (this.mode === 'VORTEX') {
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          p.angle += p.speed;
          p.distance -= 1.2;
          if (p.distance < 10) {
            p.distance = Math.max(w, h) * 0.8;
            p.angle = Math.random() * Math.PI * 2;
          }
          
          const x = cx + Math.cos(p.angle) * p.distance;
          const y = cy + Math.sin(p.angle) * p.distance;
          
          const sizeScale = (1 - p.distance / (Math.max(w, h) * 0.8)) * 5 + 1;
          const alpha = (1 - p.distance / (Math.max(w, h) * 0.8)) * 0.8 + 0.2;
          
          this.ctx.beginPath();
          this.ctx.arc(x, y, p.radius * sizeScale, 0, Math.PI * 2);
          
          let fillStyle = 'rgba(' + Math.floor(r * p.colorScale) + ',' + Math.floor(g * p.colorScale) + ',' + Math.floor(b * p.colorScale) + ',' + alpha + ')';
          if (tId === 'theme-dakan') {
            fillStyle = 'rgba(212, 175, 55, ' + alpha + ')';
          }
          
          this.ctx.fillStyle = fillStyle;
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ', 0.5)';
          this.ctx.shadowBlur = 6;
          this.ctx.fill();
        }
        this.ctx.shadowBlur = 0;
      }
      // 9. 3D DOUBLE HELIX DNA (Science & Bio beauty)
      else if (this.mode === 'DNA') {
        const time = Date.now() * 0.0015;
        const padding = 60;
        const activeHeight = h - padding * 2;
        const radiusX = Math.min(w * 0.15, 120);
        
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          const y = padding + p.yPos * activeHeight;
          const theta = p.phase + time;
          
          const xA = cx + Math.sin(theta) * radiusX;
          const zA = Math.cos(theta);
          
          const xB = cx + Math.sin(theta + Math.PI) * radiusX;
          const zB = Math.cos(theta + Math.PI);
          
          const alphaConnector = ((zA + zB) / 2 + 2) / 4 * 0.25 + 0.1;
          this.ctx.beginPath();
          this.ctx.moveTo(xA, y);
          this.ctx.lineTo(xB, y);
          this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + alphaConnector + ')';
          this.ctx.lineWidth = 2;
          this.ctx.stroke();
          
          const sizeA = (zA + 1.5) * 4 + 2;
          const alphaA = (zA + 1.2) / 2.2 * 0.7 + 0.2;
          this.ctx.beginPath();
          
          if (tId === 'theme-s-bio' || tId === 'theme-karite') {
            this.ctx.arc(xA, y, sizeA * 1.3, 0, Math.PI * 2);
          } else {
            this.ctx.arc(xA, y, sizeA, 0, Math.PI * 2);
          }
          
          this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + alphaA + ')';
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ', 0.6)';
          this.ctx.shadowBlur = 6;
          this.ctx.fill();
          
          const sizeB = (zB + 1.5) * 4 + 2;
          const alphaB = (zB + 1.2) / 2.2 * 0.7 + 0.2;
          this.ctx.beginPath();
          this.ctx.arc(xB, y, sizeB, 0, Math.PI * 2);
          this.ctx.fillStyle = 'rgba(' + Math.floor(r*0.8) + ',' + Math.floor(g*0.8) + ',' + Math.floor(b*0.8) + ',' + alphaB + ')';
          this.ctx.fill();
        }
        this.ctx.shadowBlur = 0;
      }
      // 10. 3D PLASMA HOLOGRAPHIC SPHERE (High tech fusion)
      else if (this.mode === 'SPHERE') {
        const time = Date.now() * 0.0006;
        const sphereRadius = Math.min(w, h) * 0.28;
        
        const cosRy = Math.cos(time);
        const sinRy = Math.sin(time);
        const cosRx = Math.cos(time * 0.5);
        const sinRx = Math.sin(time * 0.5);
        
        const projectedPoints = [];
        
        for(let i=0; i<this.elements.length; i++) {
          let p = this.elements[i];
          
          let x1 = p.x3d * cosRy - p.z3d * sinRy;
          let z1 = p.x3d * sinRy + p.z3d * cosRy;
          
          let y2 = p.y3d * cosRx - z1 * sinRx;
          let z2 = p.y3d * sinRx + z1 * cosRx;
          
          const scale = fov / (fov + z2);
          const x = cx + x1 * sphereRadius * scale;
          const y = cy + y2 * sphereRadius * scale;
          
          const alpha = (z2 + 1.2) / 2.2 * 0.75 + 0.15;
          const ptSize = p.radius * scale * 2.5;
          
          projectedPoints.push({x, y, z: z2, alpha, size: ptSize});
          
          this.ctx.beginPath();
          if (tId === 'theme-h-photo') {
            this.ctx.rect(x - ptSize/2, y - ptSize/2, ptSize, ptSize);
          } else {
            this.ctx.arc(x, y, ptSize, 0, Math.PI * 2);
          }
          
          this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
          this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ', 0.4)';
          this.ctx.shadowBlur = 4;
          this.ctx.fill();
        }
        
        this.ctx.shadowBlur = 0;
        for(let i=0; i<projectedPoints.length; i++) {
          const p1 = projectedPoints[i];
          let connections = 0;
          for(let j=i+1; j<projectedPoints.length; j++) {
            if(connections > 2) break;
            const p2 = projectedPoints[j];
            const dist = Math.hypot(p1.x - p2.x, p1.y - p2.y);
            if(dist < sphereRadius * 0.45) {
              connections++;
              const alphaLine = (1 - dist / (sphereRadius * 0.45)) * Math.min(p1.alpha, p2.alpha) * 0.28;
              this.ctx.beginPath();
              this.ctx.moveTo(p1.x, p1.y);
              this.ctx.lineTo(p2.x, p2.y);
              this.ctx.strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + alphaLine + ')';
              this.ctx.lineWidth = 0.8;
              this.ctx.stroke();
            }
          }
        }
      }
      // 11. 3D FLOW RIBBONS (Elegant luxury flow)
      else if (this.mode === 'FLOW') {
        const time = Date.now();
        for(let i=0; i<this.elements.length; i++) {
          let ribbon = this.elements[i];
          this.ctx.beginPath();
          
          const grad = this.ctx.createLinearGradient(0, 0, w, 0);
          grad.addColorStop(0, 'rgba(' + r + ',' + g + ',' + b + ', 0.01)');
          grad.addColorStop(0.3, 'rgba(' + Math.floor(r * 0.9) + ',' + Math.floor(g * 0.9) + ',' + Math.floor(b * 0.9) + ', 0.35)');
          grad.addColorStop(0.7, 'rgba(' + r + ',' + g + ',' + b + ', 0.35)');
          grad.addColorStop(1, 'rgba(' + r + ',' + g + ',' + b + ', 0.01)');
          
          this.ctx.strokeStyle = grad;
          this.ctx.lineWidth = ribbon.thickness;
          this.ctx.lineCap = 'round';
          
          for(let x=0; x<w; x += 10) {
            const y = ribbon.yBase + 
                      Math.sin(x * ribbon.frequency + time * ribbon.speed + ribbon.phaseOffset) * ribbon.amplitude + 
                      Math.cos(x * 0.002 - time * 0.0008) * (ribbon.amplitude * 0.4);
            
            if (x === 0) this.ctx.moveTo(x, y);
            else this.ctx.lineTo(x, y);
          }
          this.ctx.stroke();
        }
      }
      // 12. 3D HYPER-CUBE ROTATIF (Visual geometric perfection)
      else if (this.mode === 'CUBE') {
        const time = Date.now() * 0.001;
        const size = Math.min(w, h) * 0.22;
        
        const speedX = tId === 'theme-h-silicon' ? time * 0.6 : time * 0.45;
        const speedY = tId === 'theme-h-silicon' ? time * 0.8 : time * 0.6;
        const speedZ = time * 0.3;
        
        const cosX = Math.cos(speedX), sinX = Math.sin(speedX);
        const cosY = Math.cos(speedY), sinY = Math.sin(speedY);
        const cosZ = Math.cos(speedZ), sinZ = Math.sin(speedZ);
        
        const projected = [];
        
        for (let i = 0; i < this.cubeVertices.length; i++) {
          const v = this.cubeVertices[i];
          
          let y1 = v.y * cosX - v.z * sinX;
          let z1 = v.y * sinX + v.z * cosX;
          
          let x2 = v.x * cosY - z1 * sinY;
          let z2 = v.x * sinY + z1 * cosY;
          
          let x3 = x2 * cosZ - y1 * sinZ;
          let y3 = x2 * sinZ + y1 * cosZ;
          
          const scale = fov / (fov + z2 * 0.5);
          const px = cx + x3 * size * scale;
          const py = cy + y3 * size * scale;
          
          projected.push({x: px, y: py, z: z2});
        }
        
        this.ctx.lineWidth = tId === 'theme-q-ciment' ? 2.5 : 1.8;
        for (let i = 0; i < this.cubeEdges.length; i++) {
          const edge = this.cubeEdges[i];
          const pA = projected[edge[0]];
          const pB = projected[edge[1]];
          
          const depthAlpha = (2.0 - (pA.z + pB.z) / 2.0) / 2.5 * 0.75 + 0.25;
          this.ctx.beginPath();
          this.ctx.moveTo(pA.x, pA.y);
          this.ctx.lineTo(pB.x, pB.y);
          
          let strokeStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + depthAlpha + ')';
          if (tId === 'theme-q-brique') strokeStyle = 'rgba(239,68,68,' + depthAlpha + ')';
          if (tId === 'theme-h-silicon') strokeStyle = 'rgba(16,185,129,' + depthAlpha + ')';
          
          this.ctx.strokeStyle = strokeStyle;
          this.ctx.shadowColor = strokeStyle;
          this.ctx.shadowBlur = tId === 'theme-h-silicon' ? 12 : 5;
          this.ctx.stroke();
        }
        this.ctx.shadowBlur = 0;
        
        for (let i = 0; i < projected.length; i++) {
          const p = projected[i];
          const nodeSize = (1.5 - p.z * 0.3) * 6 + 2;
          const nodeAlpha = (1.5 - p.z * 0.3) * 0.75 + 0.25;
          
          this.ctx.beginPath();
          this.ctx.arc(p.x, p.y, nodeSize, 0, Math.PI * 2);
          this.ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + nodeAlpha + ')';
          this.ctx.fill();
        }
      }
      // 13. 3D SATURN PLANET WITH ORBITING RINGS (Celestial beauty)
      else if (this.mode === 'SATURN') {
        const time = Date.now();
        const planetRadius = Math.min(w, h) * 0.14;
        const tilt = 0.35;
        
        const cosT = Math.cos(tilt), sinT = Math.sin(tilt);
        const rotRingSpeed = time * 0.0003;
        
        const ringBehind = [];
        const ringFront = [];
        
        for (let i = 0; i < this.saturnRings.length; i++) {
          let p = this.saturnRings[i];
          const theta = p.theta + rotRingSpeed;
          
          const ox = Math.cos(theta) * p.rRing;
          const oy = 0;
          const oz = Math.sin(theta) * p.rRing;
          
          const rx = ox;
          const ry = oy * cosT - oz * sinT;
          const rz = oy * sinT + oz * cosT;
          
          const px = cx + rx;
          const py = cy + ry;
          const sizeScale = (rz + planetRadius*2) / (planetRadius*2) * 1.5 + 0.5;
          
          const pt = {
            x: px,
            y: py,
            z: rz,
            size: p.radius * sizeScale,
            colorScale: p.colorScale
          };
          
          if (rz < 0) ringBehind.push(pt);
          else ringFront.push(pt);
        }
        
        for (let i = 0; i < ringBehind.length; i++) {
          const pt = ringBehind[i];
          this.ctx.beginPath();
          this.ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
          this.ctx.fillStyle = 'rgba(' + Math.floor(r * pt.colorScale) + ',' + Math.floor(g * pt.colorScale) + ',' + Math.floor(b * pt.colorScale) + ', 0.38)';
          this.ctx.fill();
        }
        
        const grad = this.ctx.createRadialGradient(cx - planetRadius*0.3, cy - planetRadius*0.3, planetRadius * 0.1, cx, cy, planetRadius);
        if (tId === 'theme-neon') {
          grad.addColorStop(0, 'rgba(56, 189, 248, 1)');
          grad.addColorStop(0.7, 'rgba(3, 105, 161, 1)');
          grad.addColorStop(1, 'rgba(2, 6, 23, 1)');
        } else if (tId === 'theme-midnight') {
          grad.addColorStop(0, 'rgba(168, 85, 247, 1)');
          grad.addColorStop(0.7, 'rgba(88, 28, 135, 1)');
          grad.addColorStop(1, 'rgba(0, 0, 0, 1)');
        } else {
          grad.addColorStop(0, 'rgba(' + Math.floor(r*1.3) + ',' + Math.floor(g*1.3) + ',' + Math.floor(b*1.3) + ', 1)');
          grad.addColorStop(0.7, 'rgba(' + r + ',' + g + ',' + b + ', 1)');
          grad.addColorStop(1, 'rgba(' + Math.floor(r*0.2) + ',' + Math.floor(g*0.2) + ',' + Math.floor(b*0.2) + ', 1)');
        }
        
        this.ctx.save();
        this.ctx.shadowBlur = planetRadius * 0.35;
        this.ctx.shadowColor = 'rgba(' + r + ',' + g + ',' + b + ', 0.5)';
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, planetRadius, 0, Math.PI * 2);
        this.ctx.fillStyle = grad;
        this.ctx.fill();
        this.ctx.restore();
        
        for (let i = 0; i < ringFront.length; i++) {
          const pt = ringFront[i];
          this.ctx.beginPath();
          this.ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
          this.ctx.fillStyle = 'rgba(' + Math.floor(r * pt.colorScale) + ',' + Math.floor(g * pt.colorScale) + ',' + Math.floor(b * pt.colorScale) + ', 0.72)';
          this.ctx.fill();
        }
      }
      else if (this.mode === 'FLAME') {
        const time = Date.now() * 0.0016;
        
        // 1. Draw Fiery Magma Waves (Back to Front)
        const layers = 5;
        for (let j = layers; j > 0; j--) {
          this.ctx.beginPath();
          const zDepth = j * 0.45;
          const scale = fov / (fov + zDepth);
          
          const waveH = h * 0.7;
          const grad = this.ctx.createLinearGradient(0, waveH * scale, w, h);
          
          if (j % 2 === 0) {
            grad.addColorStop(0, 'rgba(220, 38, 38, ' + (0.35 * scale) + ')'); // Red
            grad.addColorStop(0.5, 'rgba(234, 88, 12, ' + (0.45 * scale) + ')'); // Orange
            grad.addColorStop(1, 'rgba(251, 191, 36, ' + (0.2 * scale) + ')'); // Gold
          } else {
            grad.addColorStop(0, 'rgba(234, 88, 12, ' + (0.35 * scale) + ')'); // Orange
            grad.addColorStop(0.5, 'rgba(185, 28, 28, ' + (0.45 * scale) + ')'); // Dark red
            grad.addColorStop(1, 'rgba(15, 23, 42, ' + (0.1 * scale) + ')'); // Dark charcoal
          }
          
          this.ctx.fillStyle = grad;
          
          for (let x = 0; x <= w; x += 12) {
            let amp = (35 + j * 18) * scale;
            let freq = 0.004 + j * 0.0006;
            
            const localY = h * 0.72 + 
                           Math.sin(x * freq + time * 1.2 + j) * amp + 
                           Math.cos(x * 0.003 - time * 0.6 + j * 2) * (amp * 0.45);
                           
            const px = cx + (x - cx) * scale;
            const py = cy + (localY - cy) * scale;
            
            if (x === 0) this.ctx.moveTo(px, py);
            else this.ctx.lineTo(px, py);
          }
          
          this.ctx.lineTo(w, h);
          this.ctx.lineTo(0, h);
          this.ctx.closePath();
          this.ctx.fill();
        }
        
        // 2. Draw Rising 3D Sparks / Fiery Ashes
        for (let i = 0; i < this.elements.length; i++) {
          let p = this.elements[i];
          p.y3d += p.vy3d;
          p.x3d += p.vx3d;
          const wobble = Math.sin(p.y3d * p.wobbleSpeed) * p.wobbleAmount;
          
          if (p.y3d < -h * 0.6) {
            p.y3d = h * 0.5;
            p.x3d = (Math.random() - 0.5) * w * 1.2;
          }
          
          const scale = fov / (fov + p.z3d);
          const px = cx + (p.x3d + wobble) * scale;
          const py = cy + p.y3d * scale;
          const size = p.radius * scale;
          const alpha = (2.5 - p.z3d) / 2.5 * p.colorScale * 0.8;
          
          const grad = this.ctx.createRadialGradient(px, py, size * 0.1, px, py, size * 3.0);
          grad.addColorStop(0, 'rgba(255, 255, 255, ' + alpha + ')');
          grad.addColorStop(0.3, 'rgba(251, 191, 36, ' + (alpha * 0.9) + ')'); // Gold
          grad.addColorStop(0.7, 'rgba(234, 88, 12, ' + (alpha * 0.4) + ')'); // Orange
          grad.addColorStop(1, 'rgba(220, 38, 38, 0)'); // Red fade
          
          this.ctx.beginPath();
          this.ctx.arc(px, py, size * 3.0, 0, Math.PI * 2);
          this.ctx.fillStyle = grad;
          this.ctx.fill();
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
    
    // Toggle DOM AURA
    if(theme.eff === 'AURA') {
      if(fxEngine) fxEngine.stop();
      aura.classList.add('active');
    } else {
      aura.classList.remove('active');
      if(!fxEngine) fxEngine = new DanayaFXEngine(canvas);
      fxEngine.updateTheme(theme);
      fxEngine.start();
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
    if(!window._enableSounds) return;
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

  // --- OFFLINE-FIRST TEXT-TO-SPEECH (TTS) ENGINE ---
  if (window.speechSynthesis && window.speechSynthesis.onvoiceschanged !== undefined) {
    window.speechSynthesis.onvoiceschanged = () => {
      window.speechSynthesis.getVoices();
    };
  }

  function speak(text) {
    if (!window.speechSynthesis) return;
    try {
      window.speechSynthesis.cancel();
      
      // Nettoyage phonétique pour une prononciation parfaite (ex: "FCFA" -> "francs cé èf a")
      let cleanText = text
        .replace(/FCFA/gi, " francs cé èf a ")
        .replace(/CFA/gi, " francs cé èf a ")
        .replace(/\bF\b/g, " francs ")
        .replace(/HT/gi, " hors taxe ")
        .replace(/TTC/gi, " toutes taxes comprises ");

      const utterance = new SpeechSynthesisUtterance(cleanText);
      utterance.lang = 'fr-FR';
      
      // Signature Danaya+ "Voix Mélodieuse" : Calme, douce, gracieuse et non robotique
      utterance.pitch = 1.15; // Un timbre légèrement plus haut pour plus de douceur
      utterance.rate = 0.93;  // Un rythme posé et élégant, parfait pour le client
      
      const voices = window.speechSynthesis.getVoices();
      const frVoices = voices.filter(v => v.lang.startsWith('fr'));
      let chosenVoice = null;
      
      if (frVoices.length > 0) {
        // Sélectionne les voix féminines les plus mélodieuses et haut de gamme installées
        chosenVoice = frVoices.find(v => v.name.toLowerCase().includes('google') && v.name.toLowerCase().includes('female'))
                   || frVoices.find(v => v.name.toLowerCase().includes('hortense')) // Voix Premium macOS/iOS
                   || frVoices.find(v => v.name.toLowerCase().includes('julie'))    // Voix Premium Windows
                   || frVoices.find(v => v.name.toLowerCase().includes('female'))
                   || frVoices.find(v => v.name.toLowerCase().includes('google'))   // Voix Google standard
                   || frVoices[0]; // Repli par défaut
      }
      
      if (chosenVoice) {
        utterance.voice = chosenVoice;
      }
      
      window.speechSynthesis.speak(utterance);
    } catch (e) {
      console.error('[Danaya+ TTS Error]', e);
    }
  }

  function connect() {
    const wsUrl = (window.location.protocol === 'https:' ? 'wss://' : 'ws://') + window.location.host + '/ws?key=$encodedKey';
    const ws = new WebSocket(wsUrl);
    const dot = document.getElementById('status-dot');
    ws.onopen = () => { 
      dot.classList.add('online'); 
      window.retryCount = 0;
      console.log('[Danaya+] Display WebSocket connected');
      if (window._enableTTS) {
        speak("Afficheur client connecté. Bienvenue.");
      }
    };
    ws.onmessage = (e) => {
      window.retryCount = 0;
      try {
        const d = JSON.parse(e.data);
        if(d.type === 'play_sound') playSound(d.payload.sound);
        if(d.type === 'cart_updated') {
           const prevItems = window._lastCartItems || [];
           const newItems = d.payload.items || [];
           window._lastCartItems = newItems;

           renderCart(d.payload);
           
           if(newItems.length > 0) {
             playSound('scan_success');
           }
        }
        if(d.type === 'theme_updated') { 
          if(d.payload.use3D !== undefined) window._use3DEnabled = d.payload.use3D;
          if(d.payload.isVoiceEnabled !== undefined) window._enableTTS = d.payload.isVoiceEnabled;
          if(d.payload.enableVoiceConfig !== undefined) {
            window._enableVoiceConfig = d.payload.enableVoiceConfig;
            const btn = document.getElementById('voice-setup-trigger');
            if(btn) btn.style.display = d.payload.enableVoiceConfig ? 'flex' : 'none';
          }
          if(d.payload.theme) applyTheme(d.payload.theme); 
          if(d.payload.shopName) document.getElementById('shop-label').innerText = d.payload.shopName;
          if(d.payload.use3D !== undefined) toggleDanayaFX(window._use3DEnabled);
        }
        if(d.type === 'settings_updated') {
          if(d.payload.use3D !== undefined) window._use3DEnabled = d.payload.use3D;
          if(d.payload.isVoiceEnabled !== undefined) window._enableTTS = d.payload.isVoiceEnabled;
          if(d.payload.enableVoiceConfig !== undefined) {
            window._enableVoiceConfig = d.payload.enableVoiceConfig;
            const btn = document.getElementById('voice-setup-trigger');
            if(btn) btn.style.display = d.payload.enableVoiceConfig ? 'flex' : 'none';
          }
          if(d.payload.enableSounds !== undefined) window._enableSounds = d.payload.enableSounds;
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
          if (window._enableTTS) {
            const totalVal = d.payload.total || 0;
            const changeVal = d.payload.change || 0;
            
            let txt = "Encaissement réussi. Montant total : " + numberToWordsFr(totalVal) + " " + currency + ".";
            if (changeVal > 0) {
              txt += " Monnaie à vous rendre : " + numberToWordsFr(changeVal) + " " + currency + ".";
            }
            
            // Profil vocal doux / mots d'accompagnement
            const tId = window._currentTheme || 'theme-luxury';
            let sweetWord = "Merci infiniment pour votre confiance et au plaisir de vous revoir bientôt !";
            
            if (tId.includes('theme-rose') || tId.includes('theme-karite') || tId.includes('cosmetique') || tId.includes('mode') || tId.includes('beauty')) {
              sweetWord = "Merci infiniment pour votre visite. Prenez bien soin de vous et à très bientôt chez nous !";
            } else if (tId.includes('luxury') || tId.includes('corporate') || tId.includes('wallstreet')) {
              sweetWord = "Nous vous remercions sincèrement pour votre confiance et votre fidélité. Excellente journée à vous.";
            } else if (tId.includes('sugu') || tId.includes('supermarche') || tId.includes('grocery') || tId.includes('express')) {
              sweetWord = "Merci pour vos achats chez nous ! Passez une merveilleuse journée et à très bientôt !";
            } else if (tId.includes('quincaillerie') || tId.includes('metal')) {
              sweetWord = "Merci pour votre achat et bon travail à vous. À bientôt !";
            }
            
            txt += " " + sweetWord;
            speak(txt);
          }
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
 
  window._use3DEnabled = $use3D;
  window._enableTTS = $enableVoice;
  window._enableVoiceConfig = $enableVoiceConfig;
  window._enableSounds = $enableSounds;
 
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

  // --- DYNAMIC VOICES CONFIG PANEL & PERSISTENCE ---
  function toggleVoicePanel() {
    const p = document.getElementById('voice-panel');
    p.classList.toggle('active');
    if (p.classList.contains('active')) {
      populateVoiceList();
      
      // Load saved slider values if any
      const savedPitch = localStorage.getItem('danaya_voice_pitch');
      const savedRate = localStorage.getItem('danaya_voice_rate');
      if (savedPitch) {
        document.getElementById('vp-pitch').value = savedPitch;
        updatePitchVal(savedPitch);
      }
      if (savedRate) {
        document.getElementById('vp-rate').value = savedRate;
        updateRateVal(savedRate);
      }
    }
  }

  function updatePitchVal(v) {
    document.getElementById('vp-pitch-val').innerText = v;
  }

  function updateRateVal(v) {
    document.getElementById('vp-rate-val').innerText = v;
  }

  let localVoices = [];
  function populateVoiceList() {
    if (!window.speechSynthesis) return;
    const select = document.getElementById('vp-voice-select');
    localVoices = window.speechSynthesis.getVoices().filter(v => v.lang.startsWith('fr'));
    
    select.innerHTML = '';
    if (localVoices.length === 0) {
      select.innerHTML = '<option value="">Aucune voix française détectée</option>';
      return;
    }
    
    // Read saved settings
    const savedName = localStorage.getItem('danaya_voice_name') || '';
    
    localVoices.forEach((v, idx) => {
      const opt = document.createElement('option');
      opt.value = idx;
      opt.innerText = v.name + (v.localService ? ' [Hors-ligne]' : '');
      if (v.name === savedName || (savedName === '' && v.name.toLowerCase().includes('female'))) {
        opt.selected = true;
      }
      select.appendChild(opt);
    });
  }

  // Reload voices when speech synthesis is ready
  if (window.speechSynthesis) {
    if (window.speechSynthesis.onvoiceschanged !== undefined) {
      const prevOnVoicesChanged = window.speechSynthesis.onvoiceschanged;
      window.speechSynthesis.onvoiceschanged = () => {
        if (prevOnVoicesChanged) prevOnVoicesChanged();
        populateVoiceList();
      };
    }
  }

  function testVoice() {
    const select = document.getElementById('vp-voice-select');
    const idx = select.value;
    const pitch = parseFloat(document.getElementById('vp-pitch').value);
    const rate = parseFloat(document.getElementById('vp-rate').value);
    
    if (idx === "") return;
    const v = localVoices[idx];
    
    window.speechSynthesis.cancel();
    const txt = "Bonjour ! Bienvenue chez nous. Le total est de quinze mille francs cé èf a.";
    const utterance = new SpeechSynthesisUtterance(txt);
    utterance.lang = 'fr-FR';
    utterance.voice = v;
    utterance.pitch = pitch;
    utterance.rate = rate;
    
    window.speechSynthesis.speak(utterance);
  }

  function saveVoiceSettings() {
    const select = document.getElementById('vp-voice-select');
    const idx = select.value;
    const pitch = document.getElementById('vp-pitch').value;
    const rate = document.getElementById('vp-rate').value;
    
    if (idx !== "") {
      const v = localVoices[idx];
      localStorage.setItem('danaya_voice_name', v.name);
    }
    localStorage.setItem('danaya_voice_pitch', pitch);
    localStorage.setItem('danaya_voice_rate', rate);
    
    // Quick success voice test
    speak("Préférences de voix enregistrées avec succès.");
    
    // Close panel
    setTimeout(toggleVoicePanel, 1200);
  }
</script>

  <!-- DYNAMIC MERCHANT AUDIO & VOICE PANEL -->
  <div class="voice-setup-trigger" id="voice-setup-trigger" onclick="toggleVoicePanel()" title="Configuration Audio" style="display: ${enableVoiceConfig ? 'flex' : 'none'};">
    <svg viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
  </div>
  
  <div class="voice-panel" id="voice-panel">
    <div class="vp-header">
      <span class="vp-title">🎤 Paramètres Vocaux Danaya+</span>
      <span class="vp-close" onclick="toggleVoicePanel()">×</span>
    </div>
    
    <div class="vp-row">
      <span class="vp-label">Choisir la Voix (Dynamique)</span>
      <select class="vp-select" id="vp-voice-select"></select>
    </div>
    
    <div class="vp-row">
      <span class="vp-label">Timbre (Pitch)</span>
      <div class="vp-slider-container">
        <input type="range" class="vp-slider" id="vp-pitch" min="0.5" max="2.0" step="0.05" value="1.15" oninput="updatePitchVal(this.value)">
        <span class="vp-val" id="vp-pitch-val">1.15</span>
      </div>
    </div>
    
    <div class="vp-row">
      <span class="vp-label">Vitesse de Lecture</span>
      <div class="vp-slider-container">
        <input type="range" class="vp-slider" id="vp-rate" min="0.5" max="2.0" step="0.05" value="0.93" oninput="updateRateVal(this.value)">
        <span class="vp-val" id="vp-rate-val">0.93</span>
      </div>
    </div>
    
    <div class="vp-row" style="margin-top: 6px;">
      <button class="vp-btn" onclick="testVoice()">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="margin-right:2px;"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>
        Tester la voix
      </button>
      <button class="vp-btn vp-btn-secondary" onclick="saveVoiceSettings()">
        Enregistrer les Préférences
      </button>
    </div>
  </div>
</body>
</html>
''';
}
