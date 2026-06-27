import json

path = r'c:\Censure\gestion de stock pro offline\gestion_stock_pro_offline\lib\core\network\customer_display_html.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define the clean themes dictionary
# We use \\' to ensure Dart outputs \' to JavaScript
themes_js = """
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
    'theme-arctic': { bg:'#0c4a6e', p:'#ffffff', txt:'#0c4a6e', a:'#0284c7', m:'#0369a1', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#7dd3fc', s:'Arctic Frost ❄️', sub:'Clarté & Précision', q:'La transparence est le fondement de la confiance.', qa:'CONFUCIUS', eff:'AURA' },
    'theme-swiss': { bg:'#0f172a', p:'#ffffff', txt:'#0f172a', a:'#94a3b8', m:'#475569', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#cbd5e1', s:'Swiss Vault 🏦', sub:'Sécurité & Confiance', q:'La confiance est le capital le plus précieux.', qa:'SUISSE', eff:'NET' },
    'theme-royal': { bg:'#022c22', p:'#ffffff', txt:'#022c22', a:'#d4af37', m:'#064e3b', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#fbbf24', s:'Royal Mint 👑', sub:'Prestige Intemporel', q:'L’excellence n’est pas un acte, mais une habitude.', qa:'ARISTOTE', eff:'AURA' },
    'theme-platinum': { bg:'#f8fafc', p:'#ffffff', txt:'#1e3a8a', a:'#1e3a8a', m:'#475569', b:'rgba(0,0,0,0.04)', bt:'#ffffff', ba:'#3b82f6', s:'Platinum Trust 💎', sub:'Service Exclusif', q:'Le vrai luxe exige des matériaux vrais.', qa:'DIOR', eff:'NET' },
    'theme-wallstreet': { bg:'#111827', p:'#ffffff', txt:'#111827', a:'#2563eb', m:'#374151', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#3b82f6', s:'Wall Street 📈', sub:'Ambition & Croissance', q:'Le temps, c’est de l’argent.', qa:'FRANKLIN', eff:'NET' },
    'theme-heritage': { bg:'#4a0404', p:'#ffffff', txt:'#4a0404', a:'#b87333', m:'#7f1d1d', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#d97706', s:'Heritage Bank 🏛️', sub:'Tradition & Solidité', q:'Les traditions sont le guide de l’avenir.', qa:'INCONNU', eff:'AURA' },
    'theme-obsidian': { bg:'#030712', p:'#111827', txt:'#f9fafb', a:'#e5e7eb', m:'#9ca3af', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#9ca3af', s:'Obsidian Wealth ♠️', sub:'Discrétion & Pouvoir', q:'Le silence est l’écrin de la richesse.', qa:'ANONYME', eff:'NET' },
    'theme-monaco': { bg:'#fefce8', p:'#ffffff', txt:'#4a0404', a:'#b76e79', m:'#831843', b:'rgba(0,0,0,0.04)', bt:'#ffffff', ba:'#f43f5e', s:'Monaco Private 🛥️', sub:'Luxe Méditerranéen', q:'La grâce est plus belle encore que la beauté.', qa:'LA FONTAINE', eff:'AURA' },
    'theme-executive': { bg:'#1e293b', p:'#ffffff', txt:'#1e293b', a:'#cbd5e1', m:'#475569', b:'rgba(0,0,0,0.06)', bt:'#ffffff', ba:'#94a3b8', s:'Executive Suite 💼', sub:'Décision & Stratégie', q:'La réussite appartient à ceux qui s’y préparent.', qa:'PROVERBE', eff:'NET' },
    'theme-imperial': { bg:'#022c22', p:'#064e3b', txt:'#ecfdf5', a:'#34d399', m:'#6ee7b7', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#10b981', s:'Imperial Jade 🐉', sub:'Prospérité & Sagesse', q:'La sagesse est la plus grande des richesses.', qa:'ASIE', eff:'AURA' },
    'theme-sovereign': { bg:'#020617', p:'#0f172a', txt:'#f8fafc', a:'#fbbf24', m:'#cbd5e1', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#f59e0b', s:'Sovereign Wealth 👑', sub:'Autorité & Majesté', q:'L’or est l’argent des rois.', qa:'PROVERBE', eff:'NET' },
    'theme-bogolan': { bg:'#2c1e16', p:'#4a3525', txt:'#f4e4d8', a:'#d2a679', m:'#8b6b52', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#e8c39e', s:'Bogolan Héritage 🏺', sub:'Terre & Authenticité', q:'La terre ne trahit jamais celui qui la cultive.', qa:'PROVERBE MALIEN', eff:'AURA' },
    'theme-empire': { bg:'#4a0e17', p:'#2b080d', txt:'#fcf3d9', a:'#d4af37', m:'#b59535', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#f5d061', s:'Or de l\\\\\\'Empire 👑', sub:'Prospérité & Puissance', q:'La patience est la clé de la richesse.', qa:'SAGESSE MANDINGUE', eff:'NET' },
    'theme-niger': { bg:'#06294a', p:'#04182b', txt:'#e8f1f8', a:'#2081c3', m:'#4b9dd1', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#6cb5e3', s:'Fleuve Niger 🌊', sub:'Fluidité & Vie', q:'L\\\\\\'eau qui coule ne se gâte jamais.', qa:'PROVERBE BAMBARA', eff:'AURA' },
    'theme-kita': { bg:'#fdfbf7', p:'#ffffff', txt:'#4a3b32', a:'#8b6e58', m:'#b59c8a', b:'rgba(0,0,0,0.04)', bt:'#ffffff', ba:'#cbb4a3', s:'Coton de Kita 🧶', sub:'Douceur & Pureté', q:'Le fil ne casse pas s\\\\\\'il est bien tissé.', qa:'TRADITION MALIENNE', eff:'NET' },
    'theme-djenne': { bg:'#8b4513', p:'#5c2e0b', txt:'#fae8d4', a:'#cd853f', m:'#e0a96d', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#f4c28f', s:'Ocre de Djenné 🏛️', sub:'Histoire & Fondation', q:'Les grands édifices commencent par une poignée de terre.', qa:'MALI', eff:'AURA' },
    'theme-timbuktu': { bg:'#e6d5a1', p:'#f5ecce', txt:'#2b2005', a:'#1d3557', m:'#457b9d', b:'rgba(0,0,0,0.05)', bt:'#2b2005', ba:'#1d3557', s:'Savoir de Tombouctou 📜', sub:'Sagesse & Lumière', q:'La sagesse est la plus grande des richesses.', qa:'SAGE DE TOMBOUCTOU', eff:'NET' },
    'theme-bazin': { bg:'#0d1b2a', p:'#1b263b', txt:'#e0e1dd', a:'#778da9', m:'#415a77', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#a3b1c6', s:'Bazin Riche 💎', sub:'Élégance & Prestige', q:'L\\\\\\'habit ne fait pas le moine, mais il impose le respect.', qa:'PROVERBE MALIEN', eff:'NET' },
    'theme-bamako': { bg:'#e65c00', p:'#cc5200', txt:'#fff0e6', a:'#ffcc00', m:'#ff9933', b:'rgba(0,0,0,0.1)', bt:'#ffffff', ba:'#ffeb99', s:'Soleil de Bamako ☀️', sub:'Chaleur & Accueil', q:'L\\\\\\'étranger a de grands yeux mais il ne voit rien, guide-le.', qa:'HOSPITALITÉ MALIENNE', eff:'AURA' },
    'theme-bandiagara': { bg:'#7b6b59', p:'#54483c', txt:'#f0ebe1', a:'#c4b095', m:'#a6947d', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#e0cca6', s:'Falaise Dogon ⛰️', sub:'Force & Élévation', q:'C\\\\\\'est au bout de la vieille corde qu\\\\\\'on tisse la nouvelle.', qa:'SAGESSE DOGON', eff:'NET' },
    'theme-karite': { bg:'#2a4d33', p:'#1e3825', txt:'#f5faeb', a:'#a3b18a', m:'#dad7cd', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#c1ccb1', s:'Karité Précieux 🌿', sub:'Ressource & Bien-être', q:'L\\\\\\'arbre de la patience a des fruits très doux.', qa:'PROVERBE MALIEN', eff:'AURA' },
    'theme-sugu': { bg:'#8b0000', p:'#660000', txt:'#fff0f5', a:'#ff4500', m:'#ff8c00', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#ff6347', s:'Sugu Ba (Grand Marché) 🛍️', sub:'Dynamisme & Négoce', q:'Le marché est le cœur du monde.', qa:'SUGU', eff:'NET' },
    'theme-djoula': { bg:'#022c22', p:'#064e3b', txt:'#ecfdf5', a:'#fbbf24', m:'#10b981', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#fcd34d', s:'Djoula Saba (Négoce) 🤝', sub:'Affaires & Prospérité', q:'Un bon commerçant a toujours le sourire.', qa:'DJOULA', eff:'AURA' },
    'theme-wariba': { bg:'#422006', p:'#713f12', txt:'#fef3c7', a:'#f59e0b', m:'#d97706', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#fbbf24', s:'Wari Ba (Fortune) 💰', sub:'Richesse & Croissance', q:'L’argent ne fait pas de bruit, mais il construit.', qa:'WARI', eff:'NET' },
    'theme-dakan': { bg:'#2e1065', p:'#4c1d95', txt:'#f5f3ff', a:'#c084fc', m:'#8b5cf6', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#d8b4fe', s:'Dakan (Le Succès) 🌟', sub:'Destinée & Ambition', q:'Le succès est au bout de l’effort.', qa:'DAKAN', eff:'AURA' },
    'theme-musso': { bg:'#4c0519', p:'#831843', txt:'#fff1f2', a:'#fb7185', m:'#e11d48', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#fda4af', s:'Musso Sira (Femmes) 👩🏾‍💼', sub:'Vision & Élégance', q:'La femme qui entreprend bâtit la nation.', qa:'MUSSO', eff:'AURA' },
    'theme-garabal': { bg:'#451a03', p:'#78350f', txt:'#fef3c7', a:'#d97706', m:'#b45309', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#f59e0b', s:'Garabal (Agrobusiness) 🐂', sub:'Force & Terre', q:'La terre est le vrai trésor de l’homme.', qa:'GARABAL', eff:'NET' },
    'theme-sanife': { bg:'#083344', p:'#164e63', txt:'#ecfeff', a:'#22d3ee', m:'#06b6d4', b:'rgba(255,255,255,0.06)', bt:'#ffffff', ba:'#67e8f9', s:'Sani Fè (L\\\\\\'Excellence) 💎', sub:'Achats Précieux', q:'Ce qui a de la valeur mérite d’être soigné.', qa:'SANI', eff:'AURA' },
    'theme-jago': { bg:'#0f172a', p:'#1e293b', txt:'#f8fafc', a:'#94a3b8', m:'#64748b', b:'rgba(255,255,255,0.08)', bt:'#ffffff', ba:'#cbd5e1', s:'Jago Kènè (Affaires) 🏢', sub:'Sérieux & Corporate', q:'Les bonnes affaires se font dans la confiance.', qa:'JAGO', eff:'NET' },
    'theme-faso': { bg:'#064e3b', p:'#14532d', txt:'#f0fdf4', a:'#facc15', m:'#dc2626', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#fef08a', s:'Faso Jugu (Bâtisseur) 🇲🇱', sub:'Patriotisme & Économie', q:'C’est ensemble qu’on construit la nation.', qa:'FASO', eff:'AURA' },
    'theme-ton': { bg:'#3f3f46', p:'#52525b', txt:'#fafafa', a:'#d4d4d8', m:'#a1a1aa', b:'rgba(255,255,255,0.05)', bt:'#ffffff', ba:'#e4e4e7', s:'Ton Ba (Coopérative) 🤝', sub:'Solidarité & Réseau', q:'L’union fait la force du commerce.', qa:'TON', eff:'NET' }
  };
""".strip()

# We want to replace everything from "  const themes = {" to "  };"
import re
new_content = re.sub(r'const themes = \{.*?\}\s*;', themes_js + ';', content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
