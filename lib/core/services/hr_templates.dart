class HrTemplates {
  static const Map<String, String> allContracts = {
    'CDI Classique': '''<h1>CONTRAT DE TRAVAIL À DURÉE INDÉTERMINÉE (CDI)</h1>
<br>
<p><strong>ENTRE LES SOUSSIGNÉS :</strong></p>
<p>La société <strong>[BOUTIQUE]</strong>, dont le siège social est situé à [ADRESSE], représentée par sa Direction Générale, désignée ci-après « L'Employeur », d'une part,</p>
<br>
<p>ET</p>
<br>
<p>Monsieur/Madame <strong>[NOM_EMPLOYE]</strong>, né(e) le [DATE_NAISSANCE], domicilié(e) à [ADRESSE], désigné(e) ci-après « Le Salarié », d'autre part.</p>
<br>
<p><strong>IL A ÉTÉ CONVENU ET ARRÊTÉ CE QUI SUIT :</strong></p>
<br>
<h2>Article 1 : Engagement et Fonction</h2>
<p>Le Salarié est engagé par L'Employeur dans le cadre d'un Contrat à Durée Indéterminée (CDI) à compter du <strong>[DATE_DEBUT]</strong>, en qualité de <strong>[POSTE]</strong> au sein du département <strong>[DEPARTEMENT]</strong>.</p>
<p>Le Salarié exercera ses fonctions sous l'autorité de la Direction ou de toute autre personne qui pourrait lui être substituée.</p>
<br>
<h2>Article 2 : Période d'Essai</h2>
<p>Le présent contrat est conclu sous réserve d'une période d'essai de trois (3) mois, éventuellement renouvelable une fois. Durant cette période, chacune des parties pourra rompre le contrat sans indemnité.</p>
<br>
<h2>Article 3 : Rémunération</h2>
<p>En contrepartie de ses services, Le Salarié percevra une rémunération mensuelle de base de <strong>[SALAIRE] [DEVISE]</strong> brute. Cette rémunération est versée à la fin de chaque mois calendaire.</p>
<br>
<h2>Article 4 : Horaires de Travail</h2>
<p>Le Salarié est soumis à la durée légale du travail en vigueur dans l'entreprise. Ses horaires pourront être aménagés selon les nécessités de service.</p>
<br>
<h2>Article 5 : Confidentialité et Secret Professionnel</h2>
<p>Le Salarié s'engage à observer la plus stricte discrétion sur toutes les informations, procédés, ou méthodes dont il pourrait avoir connaissance dans l'exercice de ses fonctions.</p>
<br>
<h2>Article 6 : Rupture du Contrat</h2>
<p>À l'issue de la période d'essai, la rupture du contrat s'effectuera conformément aux dispositions légales en vigueur, moyennant le respect d'un préavis d'un (1) mois, sauf cas de faute grave ou lourde.</p>
<br>
<p>Fait en double exemplaire à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>Le Salarié</strong> <em>(Signature précédée de la mention "Lu et approuvé")</em> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>L'Employeur</strong> <em>(Signature et Cachet)</em></p>
''',
    
    'CDD Standard': '''<h1>CONTRAT DE TRAVAIL À DURÉE DÉTERMINÉE (CDD)</h1>
<br>
<p><strong>ENTRE LES SOUSSIGNÉS :</strong></p>
<p>La société <strong>[BOUTIQUE]</strong>, dont le siège social est situé à [ADRESSE], désignée ci-après « L'Employeur », d'une part,</p>
<br>
<p>ET</p>
<br>
<p>Monsieur/Madame <strong>[NOM_EMPLOYE]</strong>, désigné(e) ci-après « Le Salarié », d'autre part.</p>
<br>
<p><strong>IL A ÉTÉ CONVENU ET ARRÊTÉ CE QUI SUIT :</strong></p>
<br>
<h2>Article 1 : Objet et Motif</h2>
<p>Le présent contrat à durée déterminée est conclu afin de pourvoir au poste de <strong>[POSTE]</strong> dans le département <strong>[DEPARTEMENT]</strong>, pour répondre à un besoin ponctuel de l'entreprise.</p>
<br>
<h2>Article 2 : Durée</h2>
<p>Ce contrat est conclu pour une durée déterminée de <strong>[DUREE] mois</strong>. Il prendra effet le <strong>[DATE_DEBUT]</strong> et s'achèvera automatiquement le <strong>[DATE_FIN]</strong>.</p>
<br>
<h2>Article 3 : Rémunération</h2>
<p>Pour l'exécution de ses missions, Le Salarié percevra un salaire mensuel de base de <strong>[SALAIRE] [DEVISE]</strong>. À l'issue du contrat, une prime de précarité pourra être versée selon les conditions légales.</p>
<br>
<h2>Article 4 : Obligation de Discrétion</h2>
<p>Le Salarié s'engage à ne divulguer aucune information confidentielle concernant L'Employeur, ses clients ou ses partenaires.</p>
<br>
<p>Fait en double exemplaire à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>Le Salarié</strong> <em>(Lu et approuvé)</em> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>L'Employeur</strong></p>
''',

    'Avertissement Disciplinaire': '''<h1>AVERTISSEMENT DISCIPLINAIRE</h1>
<br>
<p><strong>De :</strong> La Direction, [BOUTIQUE]</p>
<p><strong>À l'attention de :</strong> Monsieur/Madame [NOM_EMPLOYE]</p>
<p><strong>Poste occupé :</strong> [POSTE]</p>
<p><strong>Date :</strong> [DATE_JOUR]</p>
<br>
<p><strong>Objet : Avertissement pour manquement aux obligations professionnelles</strong></p>
<br>
<p>Monsieur/Madame,</p>
<br>
<p>Par la présente, nous sommes au regret de vous adresser un avertissement formel suite aux faits constatés récemment dans le cadre de vos fonctions.</p>
<p>En effet, nous avons dû déplorer un comportement inapproprié / un non-respect de vos obligations, qui perturbe le bon fonctionnement de notre entreprise.</p>
<p>Nous vous demandons instamment de rectifier votre comportement sans délai. Nous vous rappelons que la poursuite de tels agissements ou de nouvelles fautes pourraient nous conduire à envisager des sanctions disciplinaires plus lourdes, pouvant aller jusqu'au licenciement.</p>
<br>
<p>Nous espérons que vous saurez tirer parti de cette mise en garde et que nous constaterons une amélioration rapide.</p>
<br>
<p>Veuillez agréer, Monsieur/Madame, l'expression de nos salutations distinguées.</p>
<br>
<p><strong>La Direction</strong></p>
<br>
<p><em>Signature du salarié (pour remise en main propre) :</em></p>
''',

    'Attestation de Stage': '''<h1>ATTESTATION DE STAGE</h1>
<br>
<p>Nous soussignés, la société <strong>[BOUTIQUE]</strong>, sise à [ADRESSE], représentée par sa Direction Générale,</p>
<br>
<p>Certifions par la présente que :</p>
<br>
<p>Monsieur/Madame <strong>[NOM_EMPLOYE]</strong></p>
<p>Né(e) le [DATE_NAISSANCE]</p>
<br>
<p>a effectué un stage au sein de notre entreprise en qualité de <strong>[POSTE]</strong> dans le département <strong>[DEPARTEMENT]</strong>.</p>
<br>
<p>Ce stage s'est déroulé de manière ininterrompue du <strong>[DATE_DEBUT]</strong> au <strong>[DATE_FIN]</strong>.</p>
<p>Durant cette période, le stagiaire a fait preuve de sérieux, de motivation et a rempli les missions qui lui ont été confiées avec professionnalisme.</p>
<br>
<p>Cette attestation est délivrée pour servir et valoir ce que de droit.</p>
<br>
<p>Fait à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>La Direction</strong></p>
<p><em>(Signature et Cachet de l'entreprise)</em></p>
''',

    'Certificat de Travail': '''<h1>CERTIFICAT DE TRAVAIL</h1>
<br>
<p>Nous soussignés, la société <strong>[BOUTIQUE]</strong>, dont le siège social est situé à [ADRESSE],</p>
<br>
<p>Certifions que :</p>
<br>
<p>Monsieur/Madame <strong>[NOM_EMPLOYE]</strong> a été employé(e) dans notre société du <strong>[DATE_DEBUT]</strong> au <strong>[DATE_FIN]</strong> inclusivement.</p>
<br>
<p>Durant cette période, il/elle a occupé les fonctions de <strong>[POSTE]</strong>.</p>
<br>
<p>Monsieur/Madame [NOM_EMPLOYE] nous quitte libre de tout engagement envers notre société.</p>
<br>
<p>Le présent certificat est délivré conformément à la législation en vigueur pour servir et valoir ce que de droit.</p>
<br>
<p>Fait à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>La Direction</strong></p>
<p><em>(Signature et Cachet)</em></p>
''',

    'Reçu pour Solde de Tout Compte': '''<h1>REÇU POUR SOLDE DE TOUT COMPTE</h1>
<br>
<p><strong>Je soussigné(e),</strong> Monsieur/Madame <strong>[NOM_EMPLOYE]</strong>, demeurant à [ADRESSE],</p>
<br>
<p>Reconnais avoir reçu ce jour de la société <strong>[BOUTIQUE]</strong>, pour le règlement de mon solde de tout compte suite à la rupture de mon contrat de travail, la somme totale de :</p>
<br>
<h3>[SALAIRE] [DEVISE]</h3>
<br>
<p>Ce montant inclut les salaires restants, les éventuelles indemnités compensatrices de congés payés, et toute autre prime ou indemnité due en vertu de la législation en vigueur ou de mon contrat.</p>
<br>
<p>En conséquence, je donne à la société [BOUTIQUE] quittance entière et définitive pour toutes les sommes qui m'étaient dues à l'occasion de l'exécution et de la cessation de mon contrat de travail.</p>
<br>
<p>Ce reçu est établi en double exemplaire original, dont un m'a été remis ce jour.</p>
<br>
<p>Fait à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>Le Salarié</strong></p>
<p><em>(Écrire de façon manuscrite "Pour solde de tout compte" suivi de la signature)</em></p>
''',

    'Demande de Congés': '''<h1>FORMULAIRE DE DEMANDE DE CONGÉS</h1>
<br>
<p><strong>Informations sur le collaborateur :</strong></p>
<ul>
  <li><strong>Nom de l'employé :</strong> [NOM_EMPLOYE]</li>
  <li><strong>Poste occupé :</strong> [POSTE]</li>
  <li><strong>Département :</strong> [DEPARTEMENT]</li>
</ul>
<br>
<h2>Détails de la demande</h2>
<p>Je sollicite par la présente l'accord de la direction pour prendre un congé payé/sans solde couvrant la période suivante :</p>
<p><strong>Date de début :</strong> [DATE_DEBUT]</p>
<p><strong>Date de fin (inclusive) :</strong> [DATE_FIN]</p>
<br>
<p>Je m'engage à organiser la passation de mes dossiers en cours avant mon départ afin de ne pas perturber la bonne marche du service.</p>
<br>
<p>Fait à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>Le Salarié</strong> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>La Direction (Accord/Refus)</strong></p>
''',

    'Accord de Confidentialité (NDA)': '''<h1>ACCORD DE CONFIDENTIALITÉ ET DE NON-DIVULGATION (NDA)</h1>
<br>
<p><strong>ENTRE :</strong></p>
<p>La société <strong>[BOUTIQUE]</strong>, d'une part,</p>
<p>ET Monsieur/Madame <strong>[NOM_EMPLOYE]</strong>, exerçant la fonction de <strong>[POSTE]</strong>, d'autre part.</p>
<br>
<h2>Article 1 : Définition des Informations Confidentielles</h2>
<p>Sont considérées comme strictement confidentielles toutes les informations commerciales, financières, techniques, ou stratégiques appartenant à [BOUTIQUE], transmises au Salarié dans le cadre de ses fonctions.</p>
<br>
<h2>Article 2 : Engagements</h2>
<p>Le Salarié s'engage formellement à :</p>
<ul>
  <li>Garder le secret absolu sur les Informations Confidentielles.</li>
  <li>Ne pas utiliser ces informations à des fins personnelles ou pour le compte d'un tiers.</li>
  <li>Restituer l'intégralité des documents confidentiels lors de son départ.</li>
</ul>
<br>
<h2>Article 3 : Sanctions</h2>
<p>Toute violation du présent accord de confidentialité pourra entraîner des poursuites pénales et civiles pour réparation des préjudices subis, indépendamment des sanctions disciplinaires pouvant aller jusqu'au licenciement immédiat.</p>
<br>
<p>Fait à [ADRESSE], le [DATE_JOUR].</p>
<br>
<p><strong>Le Salarié</strong> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>La Direction</strong></p>
''',

    'Promesse d\'Embauche': '''<h1 style="text-align: center;">PROMESSE D'EMBAUCHE</h1>
<br>
<p><strong>De :</strong> La Direction, [BOUTIQUE]</p>
<p><strong>À l'attention de :</strong> Monsieur/Madame [NOM_EMPLOYE]</p>
<p><strong>Date :</strong> [DATE_JOUR]</p>
<br>
<p>Monsieur/Madame,</p>
<br>
<p>Suite à nos récents entretiens, nous avons le plaisir de vous confirmer notre volonté de vous engager au sein de notre société [BOUTIQUE].</p>
<br>
<p>Les conditions principales de votre embauche sont les suivantes :</p>
<ul>
  <li><strong>Poste :</strong> [POSTE] au sein du département [DEPARTEMENT].</li>
  <li><strong>Date d'entrée en fonction :</strong> [DATE_DEBUT].</li>
  <li><strong>Rémunération :</strong> Un salaire de base mensuel brut de [SALAIRE] [DEVISE].</li>
</ul>
<br>
<p>Cette promesse d'embauche est valable jusqu'au [DATE_FIN]. Au-delà de cette date, sans retour signé de votre part, la présente offre sera considérée comme caduque.</p>
<p>Dans l'attente du plaisir de vous accueillir parmi nos collaborateurs, nous vous prions d'agréer l'expression de nos sincères salutations.</p>
<br>
<p><strong>La Direction</strong></p>
<br>
<p><em>Signature du candidat (Précédée de "Bon pour accord") :</em></p>
'''
  };

  static const Map<String, String> allReports = {};
}
