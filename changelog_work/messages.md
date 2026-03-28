Flonflon — 18-Jul-25 10:47 AM
Je viens de voir pour ton logiciel de première écoute
C'est quoi ce poulet ??
Maxime Janvier [ELXR],  — 18-Jul-25 9:11 PM
C'est un pouler qui sent bon le rôti sur le marché un dimanche matin. 🍗 

Plus sérieusement, j'ai vu ta réponse et repasser le passage en stream de ce matin (et tous les gentils messages du chat). Content que tu sois dithyrambique sur le projet et ça me ferait plaisir de t'accompagner pour qu'on l'integres completement dans le stream.

C'était le but de monter cette démo: montrer que c'est possible, susciter l'intérêt avec du tangible et pas une promesse (ou pire une diapo PPT). Mon flow de travail fait que j'essayes de toujours avoir un produit utilisable. Tu parlais de l'utiliser dès lundi, j'y ai réfléchi aujourd'hui, je penses qu'il manques 5% pour être ok pour un test avec le chat:

le chatbot configuré qui publies les messages d'annonce est mon propre compte Lanfeust313. Il faut que je crees un compte PremiereEcoute dédié (comme Mimobotlette) et vérifier qu'il récupère les bonnes permissions de publication
Les messages du chatbot sont pas encore les bons et ils en manquent (genre annoncer les fin/debut de votes)
Et sur du plus perso, j'aimerais bien être là pour le test et lundi c'est pas possible. Pour le plaisir de le voir en live, voir les premiers retours, et monitorer si tout se passes bien.

Je rentres de vacances ce dimanche, je suis tout à fait chaud à pousser ce 5% pour faire en sorte qu'on puisses faire un premier test grandeur nature dans les jours qui viennent.

Sur le système de vote, je prevois deux choses:

Permettre de choisir le système de notation (1-10, 1-5, smash or pass,…)
Permettre le choix de voter via message ou sondage (crée automatiquement - mais ne marches qu'avec une notation à 5 choix ou moins)

1-10 via message te convient pour commencer ? Ou un autre système te sembles plus adequat ?

Est ce que le look general de l'interface te vas ? Tu est plutôt light mode ou dark mode ?

Hâte, j'ai plein de petites idées. flonflExcellent
Maxime Janvier [ELXR],  — 23-Jul-25 11:43 AM
Salut, tu peux tester https://premiere-ecoute.fly.dev/, on a une démo tout à fait jouable :angledHype: 

Tu peux faire un test hors stream, que j'ai réussi avec mon propre comtpe, avec ton Spotify/Twitch chat:

Crées ton compte avec Twitch, associes le à Spotify.
Tu peux ensuite créer une nouvelle session.
Quand tu démarres la session, si tu as un message "Cannot start session", ça peut être du au fait que ton lecteur Spotify doit être actif (une piste déjà en train de tourner) pour qu'on puisses lancer la première track.
Au démarrage/fin/nouvelle track durant la session, un bot premiereecoutebot devrait publier un message dans le chat
Tu peux noter via le chat et aussi dans l'interface pour avoir la note viewer/streamer
Cliquer sur terminer la session pour finir
 
Maxime Janvier [ELXR],  — 22-Aug-25 6:47 PM
Si jamais tu vois une chemise bleu avec des oies blanches à Rock en Seine, n'hesites pas à faire coucou
Maxime Janvier [ELXR],  — 25-Aug-25 12:20 PM
Envoies moi ton email (associé à ton compte spotify) je peux t'ajouter 
Flonflon — 25-Aug-25 12:21 PM
instaflonflon@gmail.com
Maxime Janvier [ELXR],  — 25-Aug-25 12:22 PM
vas y essayes de te connecter
Flonflon — 25-Aug-25 12:23 PM
Putain c'est good !
Maxime Janvier [ELXR],  — 25-Aug-25 12:24 PM
en vrai, on peut faire un test à la fin de l'enregistrement sur n'importe quel album pour crash-tester avec les gens
Maxime Janvier [ELXR],  — 25-Aug-25 12:45 PM
tant que tu est sur le site, tu peux mettre en place après l'enregistrement, le billboard "les 25 chansons" et faire tester aux gens, ça va te creer un formulaire pour que les gens resoumettent leur playlist sans passer par Discord. Tu n'a pas besoin de la connection Spotify pour ça. 
Image
Flonflon — 25-Aug-25 1:15 PM
plus tard pour le billboard !
Merci en tout cas ❤️
Maxime Janvier [ELXR],  — 25-Aug-25 5:50 PM
Bon, c'est tout fixé, je faisais n'imp avec l'encryption des secrets Spotify. Donc tu peux tester toutes les fonctionnalités du site, j'ai tout activé. J'ai réussi à faire 2 premières écoutes de test sans souci.

Pour la Premiere Ecoute, tu as déjà réussi à créer des albums, donc ça tu sais faire. Le plus important, c'est que ton lecteur Spotify tournes en permanence. Coupes le son plutôt que faire pause, mets une track aléatoire avant de démarrer/arrêter l'écoute. L'API Spotify est bizarre on peut pas avoir d'infos ou lancer des commandes sur le lecteur si il n'est pas actif.

Pour les votes: tu votes dans l'interface directement, les viewers votent via le chat (des messages "1" à "10"). Les votes sont toujours actifs à partir de la première seconde pour la track en cours. Les votes se mettent à jour au plus rapide de tous les 10 votes ou toutes les 5 secondes.

 Un bot PremiereEcouteBot (premiereecoute est pris......) publies dans le chat les messages "Welcome !", "<Titre de la track>" et "Good bye !" quand tu démarres, changes de titre et finis la session. Aucune permission à lui donner.

Et une demande, si tu peux stream tout le site pendant toute l'écoute, j'aimerais voir la réactivité, comment tu appréhendes et surtout comment les dizaines de votes vont mettre à jour l'interface (ce que je peux pas faire avec moi en solo dans mon chat de chaine twitch) 🙏 

🥚 Easter eggs: Tu peux mettre le vote en Smash or Pass plutôt que 1 à 10, tu peux aussi mettre le site en italien si FR_Jess est là.
et tu peux intégrer un overlay dans OBS avec la note en direct
Flonflon — 25-Aug-25 6:56 PM
Comment on passe en italien que je fasse la vanne ?
Maxime Janvier [ELXR],  — 25-Aug-25 6:57 PM
dans account dans le coin en haut à droite
Maxime Janvier [ELXR],  — 26-Aug-25 11:32 AM
bouton play ok, overlay (sans authentification) ok, et tu as une nouvelle page retro pour partager avec le chat à la fin d'une session. Tout doit être bon pour la première écoute de Sabrina.
Image
Maxime Janvier [ELXR],  — 29-Aug-25 10:08 AM
Ok, en gros ton token d'accès a expiré  à Spotify super tôt. Hesites pas à F5 si t'as re ce soucis, ça forces une mise à jour de ton token.
Maxime Janvier [ELXR],  — 29-Aug-25 8:37 PM
angledPepog Ok, tu as eu deux "gros" soucis sur la session de ce matin:

tu n'as pas réussi le passage au deuxième morceau. J'ai compris ce qu'il est s'est passé. Tu as crée la session à 09h01m22s, laissé la page ouverte (avec un nouveau token Spotify), parti au Starbucks, jamais rechargé la page et démarré la session à 10h00m19s. A 10h01m22s, le token a expiré (1h de temps de vie), et du coup paf le deuxième morceau. Recharger la page t'as donné un nouveau token pour 1h et ça s'est bien passé ensuite.

tu n'as pas réussir finir la session car le clic doit réussir à stopper la musique sur un device actif.

En soucis mineurs, j'ai aussi noté que l'overlay était en bassé définition avec du gris dans les coins et que le graphiques des morceaux était faux.

angledSip Pour qu'on ai le même vocabulaire, l'important c'est que tu ai un device actif (suivant les régles de Spotify, avec de la musique qui tournes ou pas). Le plus simple pour activer, c'est de mettre lecture, car ouvrir Spotify ne suffit pas à considérer ton ordinateur comme actif.  Un device devient inactif 10 minutes après avoir fait pause. Il devient direct inactif si tu fermes l'appli desktop. 
angledJam En retour de mon point de vue, le traffic (messages + inscriptions) qu'on a eu ce matin a à peine fait bouger le serveur (stable à 3% de CPU, 200Mo de RAM). J'ai mille fois confiance que ça sera toujours fucking stable sans cramer de ressources. Le fait que tu sois dans un endroit avec "peu de connection" comme tu en avais peur ce matin aura pas d'impact, même des sautes d'internet te feront toujours reconnecter dans un état stable car tout se fait côté serveur. 
angledGlasses Donc j'ai fait plusieurs choses, et je penses qu'on est dans un état où tu peux être complétement autonome et stable les prochaines semaines sans moi dans les parages, hésites pas à retest offline avec ton chat:

Le lecteur Spotify écrit clairement "No device" en rouge et caches les buttons "Previous", "Play", "Next" quand tu n'as pas un device actif.
Le lecteur Spotify renouvelle automatiquement le token par lui-même donc plus de problème d'expiration au bout d'une heure. Tu peux laisser la page ouverte sans la recharger pendant des heures.
Finir la session n'est plus conditionné au succès d'arrêter le lecteur. Ca va être tenté si un device est actif, mais sans être bloquant.
Les overlays sont doublés dans leurs tailles de rendus (et sans arrondi sur les bords).
J'ai fixé les hauteurs des graphiques (j'ai vérifié sur le Sabrina Carpenter).
 
Maxime Janvier [ELXR],  — 01-Sep-25 11:10 AM
Changelog:

Nouveau overlay Player avec le lecteur intégré
Tous les overlays affichent la progression du morceau via son fond violet.
Cooldown de 30 secondes sur les votes au début de chaque nouveau morceau.  Tous les overlays n'affichent les notes que quand les votes sont ouverts. Dans l'interface streamer, la track est affiché en orange (vote fermé) puis vert (vote ouvert).
Les overlays affichent les notes du morceau en cours, plus de la session en cours
Nouveau modal au login pour choisir entre le rôle streamer ou viewer
Image
Image
Maxime Janvier [ELXR],  — 02-Sep-25 9:35 PM
Changelog:

Sans les mains: La session peut passer au morceau suivant automatiquement(ou pas) après un certain temps d'attente (entre 1 et 60 secondes) reconfigurable au cours de la session.
Image
Maxime Janvier [ELXR],  — 03-Oct-25 1:09 AM
Changelog:

Nouvel invitée dans le chat: PremiereEcouteBot (qui est follower de la chaine) publieras des messages pour le démarrage de la session, les nouveaux morceaux, l'ouverture des votes et la fermeture de la session. Attention: l'effet de "Démarrer la session" prends une seconde de plus pour publier le double message, pas d'inquiétude.
Image
Maxime Janvier [ELXR],  — 13-Oct-25 1:45 AM
👀

Flonflon — 13-Oct-25 9:08 AM
Une extension?
Maxime Janvier [ELXR],  — 13-Oct-25 9:21 AM
Oui, une preuve de concept d'extension Twitch. La démo montres un truc que j'aimerais perso faire depuis longtemps: sauvegarder dans une playlist prédéfini n'importe quel morceau passant actuellement sur un stream. Sauvegarder mes coup de coeurs sur les FMF par exemple. 
mais on peut en faire plein de choses
Maxime Janvier [ELXR],  — 18-Oct-25 3:53 PM
Changelog:

Une seule première écoute peut être active à la fois (par streamer).
Le lien vers les overlays deviennents indépendants de la session et affiche la session active du streamer en cours. Il est donc possible de faire une scène OBS fixe avec.  Je conseilles les réglages suivant dans OBS pour que l'overlay ne reste pas branché à Premiere Ecoute entre des sessions; un changement de scène ou cacher l'overlay suffisant à le désactiver. Réafficher la scène ou l'overlay redémarre l'affichage avec possiblement la nouvelle session. Pour le moment, pour enchainer deux sessions d'écoute, il faut cacher et réafficher l'overlay.
Le bot Twitch annonce la fin du morceau dans 30 secondes.
 
Image
Maxime Janvier [ELXR],  — 28-Oct-25 2:38 PM
je vais reprendre la couleur des overlays "Premiere Ecoute", je trouves que le violet/rouge "bave" un peu. Est-ce que tu as choisi des couleurs pour tes émissions avec la nouvelle DA ? Et quelle serait celle des Premiere Ecoutes ?
Maxime Janvier [ELXR],  — 06-Nov-25 2:51 PM
Changelog:

Is it down right now ?: Le status de disponibilité de Premiere Ecoute est disponible sur http://status.premiere-ecoute.fr/. Tu peux l'utiliser pour voir si la plateforme n'est pas accessible ou ne l'a pas été dans les 30 derniers jours (ça n'arrivera jamais, je vise le 100% uptime).
Promo messages: Le bot suggère de s'inscrire sur Premiere Ecoute pour retrouver ces notes 1 minute après le début de la session et 10 secondes après la fin de la session
Maxime Janvier [ELXR],  — 07-Nov-25 8:43 AM
tu as réglé combien de temps sur la transition automatique ?
Flonflon — 07-Nov-25 8:43 AM
1s
Je dois mettre plus ?
Maxime Janvier [ELXR],  — 07-Nov-25 8:44 AM
mets plus, au moins 5 secondes. Ou fais les transitions manuelles avec
Image
et en désactivant:
Image
Flonflon — 07-Nov-25 8:46 AM
Bon y'a un bug qui saute un morceau meme avec 5 secodnes
Pas grave*
Maxime Janvier [ELXR],  — 07-Nov-25 9:01 AM
je rebotterais le serveur entre les deux sessions, j'ai l'impression que tu as un "double player" qui veulent tous les deux passer le morceau. Tu n'a pas la session ouverte deux fois dans deux pages ? 
Flonflon — 07-Nov-25 9:01 AM
Pas du tout
Maxime Janvier [ELXR],  — 07-Nov-25 9:52 AM
J'ai reboot le serveur pour Orelsan, fermes et rouvres toutes tes pages dans ton navigateur, et désaffiche/affiche l'overlay.
c'est bon
Maxime Janvier [ELXR],  — 09-Nov-25 1:24 PM
J'ai retourné le truc dans tous les sens. Je penses que la cause des bugs dans la session de vendredi matin, c'est deux fenetres ouvertes sur la session en même temps. A decharge, Tu adit que tu n'avais pas deux pages ouvertes et tu as verifié pendant la session. Mes preuves:

Je l'ai reproduit localement:  https://www.youtube.com/watch?v=YHTlbSbXEpc. Deux commandes de pause à Spotify en même temps (qui lances une erreur 403), deux messages Twitch quasi en même temps, on skippes deux morceaux. Ca correspond aux logs sur le serveur (erreur 403 Spotify + erreur Twitch car plus d'un message par seconde).
8 minutes avant le démarrage de la session de Rosalia, on a ces messages dans le chat:
32:43 premiereecoutebot    Les votes ferment dans 30 secondes !
33:10 premiereecoutebot    (1/15) Sexo, Violencia y Llantas
33:41 premiereecoutebot    Les votes sont ouverts !

ça pourrait si une page de session est ouverte et détectes que le player est à 30 secondes de la fin d'un morceau quelconque, puis un clic sur Précédent ou suivant.
Juste avant de lancer la session Orelsan, tu as dis: "ah ça mets pause automatiquement avant que je lances la session" (02:11:20 dans https://www.twitch.tv/videos/2611874130). C'est c'est pas supposé faire ça, ça pourrait arriver dans un cas, la page fantôme (ou ta page) est ouverte et on arrive à la fin d'un morceau sur Spotify, il va le mettre en pause.
 
Conclusion: J'arrives pas à trancher à 100% que c'est la cause. Est-ce que tu te souviendrais pas avoir ouvert un onglet 8-10 minutes avant le début de session et l'oublier quelque part ? Dans tout  les cas, j'ai renforcé les sécurités:
On ne peut plus avoir deux pages qui déclenchent la même action (manuellement ou automatiquement) au même moment. Impossible de reproduire le bug de la vidéo.
On ne déclenche pas de messages lié au player si la session n'est pas marqué comme démarré. Plus de messages parasites avant le début.
Testes le hors live pour vérifier si tu arrive à reproduire le comportement et surtout te redonner confiance dans l'outil. Je veux que tu arrives en live et ais 100% confiance que ça va être smooth as fuck. Rien de pire qu'un outil dont on est pas certain de ce qu'il va faire ou pas, c'est pas le niveau de qualité (100% uptime, 100% des sessions terminés, aucun problème visible par les/la viewers/VOD) que je vise. 🙏 
Maxime Janvier [ELXR],  — 17-Nov-25 10:16 PM
J'ai eu une idée de zinzinou (comme disent les djeuns) ce matin. Avoir le découpage en chapitres Youtube pour l'export des premières écoutes, ça t'intéresserait ? Est-ce que ce proto te semble complet ?

Maxime Janvier [ELXR],  — 19-Nov-25 9:59 PM
Changelog:

Respect des limites d'envoi des messages Twitch: Le bot respectes la limite de 1 message toutes les 30 secondes et de 20 messages toutes les 30 secondes en réessayant les messages ratés avec un délai, donc aucune perte de message mais avec des retards possibles si trop d'envois.
Command !vote: Pendant que la session est active, les viewers peuvent envoyer le message !vote pour connaitre leur moyenne sur la session en cours.
Meilleure gestion des transitions de morceaux dans les sessions d'écoute: Quand une première écoute démarre, le mode shuffle et le mode repeat de Spotify sont désactivés. A la fin d'un morceau, le lecteur se mets en pause tout seul (et affiche 00:00) sans que Premiere Ecoute fasse une pause "virtuelle". La transition au morceau suivant se fait toujours de la même façon manuellement ou automatiquement.
Chapitres Youtube: Les timestamps des transitions entre morceaux durant une première écoute sont sauvegardés et peuvent être exportés sous forme de chapitres Youtube (avec un biais de temps pour prendre en compte l'introduction de la vidéo) avec le bouton "Exporter vers Youtube" quand la session est stoppé. Voir vidéo précédente.
Sidebar: La barre de navigation à gauche peut se retracter à volonté

Comme il y a eu deux grosses améliorations (le message précédent: ⁠Flonflon⁠ et "Meilleure gestion des transitions de morceaux dans les sessions d'écoute")  et qu'il y a deux premières écoutes vendredi, je te conseilles de faire un test hors stream pour: (1) être full en confiance sur les transitions, (2) apprendreles petites différences de comportement (mode shuffle, mode repeat, pause du lecteur).

Ca devrait rouler tout seul pour vendredi 🙏  On n'est pas obligé de parler de la commande !vote, uniquement si tu veux tester (pendant ou hors du record). 
Maxime Janvier [ELXR],  — 24-Nov-25 8:35 PM
J'ai fixé le problème de la dernière première écoute. On s'est encore fait entubé par l'API Spotify angledGrumpy 

La documentation dit qu'il y au moins un nombre d'appels max par tranche de 30 secondes mais ne précises pas combien (wtf ?).
Je suis trop gourmand sur le nombre d'appels
L'API Spotify, à la fin de l'écoute après trop d'appels, répond erreur 429 (qui veut dire "Réessayes plus tard frérot, tu me casses les couilles")
L'appli avec son client d'API - qui par défaut fait 3 essais avant d'abandonner - réessayes en respectant le temps d'attente demandé par le 429 de Spotify qui est de 10 FUCKING HEURES!!! (normalement, on s'attend plutôt à des secondes). Ca aurait marché mais avec de la patience.
La page, qui attendait la réponse de l'appel, s'est mis à plus répondre à toute les interactions (ni au F5 vu qu'on commences par un appel à Spotify).

Bref,

j'ai réduit le nombre d'appels (sans dégrader l'expérience).
le client d'API est réglé pour ne plus attendre et ne plus réessayer.
La page ne freeze plus, même si il y a des erreurs 429, donc on peut arrêter la session.
Si il y a une erreur de ce style, ça sera clairement affiché en haut à droite:
Image
Maxime Janvier [ELXR],  — 19-Feb-26 12:05 AM
j'ai testé une nouvelle idée de feature: Faire une page "c'était quoi ce titre ?" comme sur Radio Nova (https://www.nova.fr/c-etait-quoi-ce-titre/). Je pense que ça pourrait en intéresser certains (moi en tout cas) pour choper des morceaux qu'on a pu entendre en stream.

Du moment où le stream se lances jusqu'à son arrêt tous les titres joués  sur le player Spotify sont récupérés pour être enregistré avec l'heure et la date de diffusion. 

Je l'ai activé pour le stream de ce soir, il est dispo sur cette page (publique): https://premiere-ecoute.fr/radio/flonflon. Tu peux configure l'activation, la visibilité de la page, et le nombre de jours de rétention dans ta page "Compte".

Intéressé ? angledPepog 
Image
Image
Flonflon — 19-Feb-26 9:15 AM
Roh la laaa
De malade
Maxime Janvier [ELXR],  — 19-Feb-26 12:20 PM
la page radio a bien fonctionné ce matin angledPepog
Flonflon — 19-Feb-26 12:39 PM
Banger
Je suis un peu tendu en ce moment mais un jour faudra parler rémunération de tout ça
Maxime Janvier [ELXR],  — 21-Feb-26 3:10 PM
je te publies un petit pavé, prends le temps de le lire, c'est important pour les prochaines premiere ecoutes. Au sujet du jour angledPepog 

Spotify et rate limiting
Améliorations
Nouveau player
Réponse
Spotify et rate limiting
Vendredi matin, le rate limiting de Spotify s'est enclenché empêchant le fonctionnement de la radio et des premières écoutes (les deux morceaux + le disque de Willow). Au vu des dernières restrictions de Spotify et du message de Neumann le même matin sur le Discord, j'en ai (trop) vite conclu que Spotify serrait la vis et que la nouvelle radio et la premiere ecoute de la veille avait suffi à enclencher. Mais en fait, non. Je me suis repenché sur les metriques du site:
Image
C'est le compteur de tous les appels d'API faits à Spotify. Le compteur revient à zéro quand une nouvelle version du site est déployé, mais sinon il ne peut que grimper. J'ai annoté les activités qu'on a eu dans la semaine: des tests que j'ai fait, la premiere ecoute du Charlie XCX et la premiere ecoute du Danny Harle. Et on voit une enorme différence entre une premiere ecoute "normale" (le charlie XCX) qui dure ~1h et consomme à peu près 10.000 appels et l'écoute du Danny Harle qui dure près de 18h (de 12h30 à 6h42 le lendemain) et consomme près de 130.000 appels mais à la même fréquence. A 6h42, vendredi matin, Spotify a commencé à enclencher le rate limiting, qui demandait un prochain essai 10 heures plus tard.

Je pense que la raison est très simple: tu as du laissé une page ouverte sur une session d'écoute qui fait tout le temps un refresh de l'état du player toute les secondes pour qu'il soit à jour. Cette mise à jour continue même après la fin de la session tant que la page est ouverte.

On reste bien sûr attentif aux évolutions et aux annonces de Spotify (les merdes). Mais pour le moment, les premieres ecoutes et la radio peuvent continuer à fonctionner, et cet incident me conforte à dire qu'on a du "budget" d'API pour continuer autant de premiere ecoutes que tu veut dans une semaine. 
Améliorations
Pour se défendre et mieux comprendre si/quand on a un incident de rate-limiting, j'ai mis en place deux choses:

Une bannière qui peut s'afficher sur tout le site (en temps-réel sans besoin de recharger la page) à la seconde où un appel à Spotify/Twitch/... déclenche un rate-limiting ce qui te permets de réagir et de connaitre le vrai status. Pas de bannière, pas de soucis. Je mets une vidéo en exemple.
Le player s'arrête automatiquement au bout de 3 heures si on laisse une page ouverte dessus. Plus de possibilité de tout consommer en 18h.
 

Nouveau player
Des bonnes nouvelles. Nouveau player, plus clair, plus beau et réglable. Tu peux choisir une couleur primaire et une couleur secondaire (dans ta page "Compte") pour faire matcher le player avec ta DA. Merci à grollbe qui m'a fait des retours sur le design. Voilà le screenshoot du design: 
Image
Réponse
Maxime Janvier [ELXR],  — 21-Feb-26 3:14 PM
Oui, ne t'inquiètes pas. Prends le temps qu'il te faut, il n'y aucune urgence ni besoin de mon côté.
Maxime Janvier [ELXR],  — 22-Feb-26 2:32 PM
Chansons courtes
Mon calcul de pourcentage pour détecter la fin des chansons était bancal pour les courtes (<1min 40). C'est fixé. J'ai aussi rajouté, pour les chansons de moins de 60 secondes, que la fenêtre de votes ouvre à 5 secondes et le message "les votes ferment dans ..." ne s'affiche pas.

J'ai testé avec l'album de Willow qui a une ouverture de 29 secondes. Nickel. 
Maxime Janvier [ELXR],  — 24-Feb-26 10:15 AM
la radio marche bien ce matin angledPepog
Maxime Janvier [ELXR],  — 24-Feb-26 4:57 PM
je suis en train de rattraper l'écoute du Willow (quel banger), idée pour la DA: ne pas afficher les messages qui ne sont qu'une note, ça laisse plus de temps pour lire les messages dans la scène qui n'affiche qu'un message.
Maxime Janvier [ELXR],  — 25-Feb-26 6:03 PM

Maxime Janvier [ELXR],  — 27-Feb-26 12:37 AM
https://youtube.com/shorts/7orOebLNZUY?si=kKolfjzshEVGAgdQ
YouTube
Lanfeust313
27 février 2026
Image
Maxime Janvier [ELXR],  — 28-Feb-26 3:19 PM
J'ai compris le bug qu'a l'API Spotify sur la mise en pause. J'ai renforcé pour contrer ça (et d'autre petits trucs). L'arrêt de la session et le skip de tracks ne devrait plus générer de messages / être bloquants. Et du coup, j'ai remis ✨ la transition automatique à partir de 1 seconde ✨.

Fluide et stable as fuck, ça peut même survivre à un redémarrage complet de l'app. Tu peux avoir confiance dans le démarrage et les transitions sans t'en inquiéter à l'écran. Je sais que t'aimes les transitions rapides, mais c'était pas désagréable les 5 secondes de pause, ça laisse le temps de  respirer/faire un comm/annoncer le prochain titre. 3/4 secondes, maybe c'est bien, si t'est en full confiance avec. 
Maxime Janvier [ELXR],  — 01-Mar-26 11:32 AM
https://www.youtube.com/watch?v=wEPF40Jy1pE
YouTube
Lanfeust313
Premiere Ecoute: Single feature
Image
Maxime Janvier [ELXR],  — 03-Mar-26 10:01 PM
https://www.youtube.com/watch?v=tkrmgHnLxOc
YouTube
Lanfeust313
Premiere Ecoute : Random Album
Image
Maxime Janvier [ELXR],  — 09-Mar-26 9:43 AM
Changelog
Nouvelle homepage:Tu peux y voir les dernières écoutes, les écoutes en cours ou planifiés. Tu peux aussi voir le status et démarrer/arrêter la radio manuellement (qui démarre/arrête toujours automatiquement avec le stream
Nouvelle page de retrospective: Dans la page "Retrospective" ou "Mes votes", cliquer sur une cover amène maintenant vers une nouvelle page dédié qui contient toutes les infos (note streamer, note chat, mes notes). Il y a des liens vers les plateformes d'écoute (Spotify for now). Tu peux aussi éditer pour rajouter des liens de replay pour lier une video Youtube / un podcast à cette page.
Image
Image
Image
Flonflon — 09-Mar-26 10:08 AM
Merci beaucoup !
Maxime Janvier [ELXR],  — 11-Mar-26 10:59 AM
Alors. C'est brut, l'interface est all over the place (et je te parle pas du code), mais ça marche. On fera les finitions si le concept marche. On a introduit la notion de "collection session", qui se différencies des listening sessions qui sont des notes sur une source primaire (album/single/playlist/...). Une collection session, c'est prendre une playlist pour recréer une nouvelle playlist en déplacant des tracks de l'un à l'autre en faisant un choix dessus.

Avec le nouveau flow, tu peux prendre deux playlists de Spotify et laisser le choix se faire en utilisant: (1) le choix du streamer, (2) le vote 1-2 du chat dans le chat, (3) le duel de tracks. Donc, à terme, tu peux t'en servir pour faire des FMF en utilisant le (1) et les playlists idéales avec (2) et (3). Démo: https://www.youtube.com/watch?v=Spm4R6vtesk
YouTube
Lanfeust313
Premiere Ecoute : Collection Session
Image
 [ELXR], 
Maxime Janvier [ELXR],  — 16-Mar-26 6:57 PM
pour la playlist idéale de la semaine pro 👆
Maxime Janvier [ELXR],  — 22-Mar-26 5:11 PM
⚠️ BREAKING CHANGE: Le lien pour le widget OBS a changé, tu peux retrouver le nouveau dans https://premiere-ecoute.fr/users/account/features en choisissant Les deux
Maxime Janvier [ELXR],  — 23-Mar-26 6:05 PM
fixed:
Image
Flonflon — 23-Mar-26 6:07 PM
❤️
Maxime Janvier [ELXR],  — 23-Mar-26 7:07 PM
l'erreur Spotify, c'est juste qu'il faut renouveller ton token Spotify. le F5 régle tout. ça sera fix angledPepog
Flonflon — 23-Mar-26 7:10 PM
Merci !
Maxime Janvier [ELXR],  — 23-Mar-26 7:36 PM
c'est Spotify qui aimes pas les doubles commandes très rapprochés, faut juste tempo et retry. ça sera fix comme l'autre en utilisant le même player que les premiere ecoutes.
Maxime Janvier [ELXR],  — 24-Mar-26 9:29 AM
j'ai une zinzinerie d'idée, mais pourquoi pas capturer les segments de commentaires avec le microphone du navigateur pendant la première écoute. Chaque segment détecté comme de la voix est enregistré (de la même manière que les segments de morceaux sont stockés). A la fin, on peut exporter un fichier XMEML pour Premiere (je découvres ce format, jamais ouvert Premiere) avec toutes les transitions marqués exactement à la durée de la sessions. J'ai une démo (on entend pas ma voix mais je suis bien en train de parler dans le micro): https://youtu.be/Qwa3BXk0qjw 
YouTube
Lanfeust313
Premiere Ecoute: Speech markers
Image
Maxime Janvier [ELXR],  — 26-Mar-26 1:24 PM
à la fin de l'ecoute quand t'as fini l'enregistrement YT cliques sur le nom de l'artiste, je t'ai mis un petit easter egg
Image
Maxime Janvier [ELXR],  — Yesterday at 11:29 AM
tu pourras essayer le button "export to premiere", ça te donnes le chapitrage des morceaux pour Premiere (pas sur à 100% que ça marche, j'ai pas encore download le free trial de premiere) 
Image
Flonflon — Yesterday at 11:58 AM
Ok !
Maxime Janvier [ELXR],  — Yesterday at 1:32 PM
Pas un bug: Il faut que ton player ait été actif dans les 10 dernières minutes pour que Premiere Ecoute puisse le relancer de lui-même. Ca évites des contrôles intempestifs depuis l'API, l'utilisateur doit être "proche de son Spotify". 