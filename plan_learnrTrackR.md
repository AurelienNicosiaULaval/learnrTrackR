# Plan complet du projet learnrTrackR

## État actuel au 2026-06-09

Le projet a dépassé le MVP initial. La version courante est `0.3.0` et doit
être considérée comme une version pilote contrôlée, pas comme une version
institutionnelle stable.

Éléments réalisés :

- squelette de package R installable;
- stockage SQLite;
- support PostgreSQL optionnel;
- suivi de tentatives simulées;
- intégration explicite avec des tutoriels `learnr`;
- helpers pour questions `learnr` et corrections `gradethis`;
- identification simple par variable d'environnement;
- scoring, gradebook et prise en compte des questions non répondues;
- exports CSV, Moodle et Canvas;
- tableau de bord Shiny local;
- configuration YAML et CSV;
- exemple de pilotage de cours;
- guide de confidentialité et fonctions de suppression, anonymisation et
  pseudonymisation;
- analyses pédagogiques et rapport enseignant;
- site pkgdown, métadonnées de citation, plan de publication et brouillon de
  papier.

Ce qui reste avant une version stable :

- exécuter un petit pilote contrôlé avec des données réelles ou semi-réelles;
- remplir le gabarit de bilan post-pilote;
- documenter les limites observées en déploiement;
- renforcer les contrôles opérationnels avant export LMS;
- finaliser une stratégie d'authentification et de rétention hors package;
- réviser le papier avec des preuves descriptives du pilote;
- archiver une release avec Zenodo et ajouter le DOI réel aux fichiers de
  citation;
- stabiliser l'API avant une éventuelle version `1.0.0`.

## 1. Vision générale du projet

Le projet vise à combler un manque important dans l’écosystème `learnr`.

Aujourd’hui, `learnr` permet de créer des tutoriels interactifs et `gradethis` permet de vérifier automatiquement des réponses et de donner de la rétroaction. Ce qui manque pour une utilisation sérieuse en contexte d’évaluation, c’est une couche complète permettant de :

- identifier les étudiant·es de manière fiable;
- enregistrer les réponses;
- enregistrer les tentatives;
- enregistrer les résultats de correction;
- produire des notes;
- exporter les résultats vers Moodle ou un autre LMS;
- fournir un tableau de bord enseignant;
- analyser les difficultés rencontrées par les étudiant·es.

L’objectif du projet est donc de développer un package R, provisoirement nommé `learnrTrackR`, qui ajoute une couche de suivi, de stockage et d’évaluation aux tutoriels `learnr`.

La philosophie générale est la suivante :

```text
learnr       = environnement interactif
gradethis    = correction et feedback
learnrTrackR = suivi, notation, export, tableau de bord
tutorizeR    = génération automatisée de tutoriels
```

Le projet ne doit pas remplacer Moodle, Posit Connect ou `learnr`. Il doit plutôt servir de pont libre, léger et contrôlable entre les tutoriels interactifs et une utilisation réelle en contexte d’enseignement évalué.

## 2. Objectifs principaux

### 2.1 Objectif pédagogique

Permettre à un enseignant d’utiliser des tutoriels `learnr` comme de vrais quiz ou devoirs interactifs évalués, sans devoir récupérer manuellement les résultats par des codes alphanumériques individuels.

### 2.2 Objectif logiciel

Créer un package R installable, documenté, testé et extensible, capable de fonctionner d’abord localement avec SQLite, puis plus tard avec PostgreSQL ou une infrastructure serveur.

### 2.3 Objectif institutionnel

Rendre possible une utilisation dans un cours universitaire avec plusieurs groupes, plusieurs tutoriels et plusieurs cohortes.

### 2.4 Objectif scientifique ou éditorial

À terme, le projet pourrait soutenir :

- une soumission à JOSE;
- une note technique sur l’évaluation interactive avec R;
- une documentation pédagogique pour les enseignants en science des données;
- une intégration future avec `tutorizeR`.

## 3. Périmètre du projet

### 3.1 Ce que le projet doit faire

Le package doit permettre :

- de déclarer un tutoriel comme suivi;
- de créer ou connecter une base de données;
- d’identifier un étudiant;
- de stocker les réponses;
- de stocker les tentatives;
- de stocker les résultats;
- de calculer une note;
- d’exporter les résultats;
- de fournir un tableau de bord enseignant;
- de produire des rapports pédagogiques.

### 3.2 Ce que le projet ne doit pas faire au départ

Le projet ne doit pas essayer de tout résoudre immédiatement.

Au départ, il ne doit pas viser :

- une authentification institutionnelle complète;
- une intégration automatique directe avec Moodle par API;
- une interface de type LMS complet;
- une analyse IA avancée;
- un déploiement multi-serveur;
- une gestion complexe des permissions.

Ces éléments peuvent être ajoutés plus tard, mais ils ne doivent pas bloquer le MVP.

## 4. Utilisateurs cibles

### 4.1 Enseignant·es

Personnes qui utilisent `learnr` ou souhaitent créer des tutoriels interactifs évaluables.

Besoins :

- créer des quiz interactifs;
- récupérer les réponses;
- noter automatiquement;
- voir les progrès;
- exporter vers Moodle;
- repérer les questions problématiques.

### 4.2 Étudiant·es

Personnes qui complètent les tutoriels.

Besoins :

- interface simple;
- feedback immédiat;
- sauvegarde fiable;
- possibilité de reprendre un tutoriel;
- éviter de perdre leurs réponses.

### 4.3 Responsables pédagogiques ou auxiliaires

Personnes qui appuient l’enseignement.

Besoins :

- suivre l’avancement;
- identifier les étudiant·es bloqué·es;
- voir les erreurs fréquentes;
- préparer des interventions ciblées.

### 4.4 Personnel TI

Personnes qui peuvent aider au déploiement.

Besoins :

- documentation claire;
- architecture simple;
- stockage sécurisé;
- configuration reproductible;
- options de déploiement.

## 5. Architecture conceptuelle

```text
Étudiant·e
   |
   v
Tutoriel learnr
   |
   v
Exercices et quiz
   |
   v
gradethis
   |
   v
Résultat de correction
   |
   v
learnrTrackR
   |
   +--> stockage SQLite
   |
   +--> stockage PostgreSQL
   |
   +--> export CSV
   |
   +--> export Moodle
   |
   +--> tableau de bord Shiny
   |
   +--> rapport pédagogique
```

## 6. Modèle de données initial

Le modèle de données doit rester simple au départ.

### 6.1 Table students

```text
student_id
student_label
email
group_id
created_at
```

Au MVP, seul `student_id` peut être obligatoire.

### 6.2 Table courses

```text
course_id
course_label
semester
created_at
```

### 6.3 Table tutorials

```text
tutorial_id
course_id
tutorial_label
version
created_at
```

### 6.4 Table questions

```text
question_id
tutorial_id
question_label
question_type
max_score
created_at
```

### 6.5 Table sessions

```text
session_id
student_id
tutorial_id
started_at
last_seen_at
completed_at
```

### 6.6 Table attempts

```text
attempt_id
session_id
student_id
tutorial_id
question_id
attempt_number
submitted_answer
grade_status
score
max_score
feedback
timestamp
```

### 6.7 Table final_scores

```text
student_id
tutorial_id
score
max_score
completion_rate
submitted_at
```

## 7. Étapes de développement

## Étape 0. Audit technique et clarification

### Objectif

Comprendre précisément comment `learnr` et `gradethis` exposent les réponses, les résultats, les événements de correction et les mécanismes de stockage existants.

### Questions à résoudre

- Comment récupérer une réponse soumise dans un exercice `learnr`?
- Comment récupérer le résultat de `gradethis`?
- Où se situe le meilleur point d’injection?
- Faut-il intercepter côté R, côté Shiny ou côté JavaScript?
- Peut-on faire un prototype sans modifier `learnr`?
- Peut-on emballer tout cela dans un package propre?
- Existe-t-il déjà des options de stockage que l’on peut réutiliser?
- Quels sont les risques de compatibilité avec les versions futures de `learnr`?

### Livrables

- `notes/architecture-notes.md`
- `notes/learnr-gradethis-hooks.md`
- un mini tutoriel de test;
- une liste des points d’injection possibles;
- une décision sur la stratégie du MVP.

### Critère de réussite

On comprend où et comment brancher la couche de suivi.

## Étape 1. Création du squelette du package

### Objectif

Créer un package R propre, minimal, installable et prêt à évoluer.

### Nom provisoire

```text
learnrTrackR
```

### Structure souhaitée

```text
learnrTrackR/
  DESCRIPTION
  NAMESPACE
  R/
    db.R
    schema.R
    track.R
    export.R
    scores.R
    dashboard.R
    utils.R
  inst/
    examples/
      minimal-learnr/
  tests/
    testthat/
  vignettes/
  man/
  README.md
  NEWS.md
  _pkgdown.yml
```

### Dépendances probables

- DBI
- RSQLite
- dplyr
- tibble
- jsonlite
- shiny
- learnr
- gradethis
- testthat
- knitr
- rmarkdown

Au départ, il vaut mieux garder les dépendances minimales.

### Fonctions minimales à créer

```r
init_tracking_db()
create_schema()
connect_tracking_db()
track_attempt()
get_attempts()
compute_scores()
export_results()
```

### Livrables

- package installable;
- README minimal;
- base SQLite initialisable;
- tests unitaires sur la base de données;
- exemple minimal sans intégration profonde avec `learnr`.

### Critère de réussite

On peut installer le package et créer une base de données de suivi vide.

## Étape 2. Prototype de stockage local

### Objectif

Permettre d’enregistrer manuellement une tentative dans une base SQLite.

### Exemple d’utilisation visé

```r
library(learnrTrackR)

db <- init_tracking_db("learnrtrackr.sqlite")

track_attempt(
  db = db,
  student_id = "demo_student",
  tutorial_id = "demo_tutorial",
  question_id = "q1",
  submitted_answer = "mean(x)",
  grade_status = "correct",
  score = 1,
  max_score = 1,
  feedback = "Correct."
)

get_attempts(db)
```

### Livrables

- création automatique du schéma;
- insertion d’une tentative;
- lecture des tentatives;
- tests de validation;
- gestion minimale des erreurs.

### Critère de réussite

On peut enregistrer, relire et exporter des tentatives simulées.

## Étape 3. Intégration minimale avec un tutoriel learnr

### Objectif

Créer un tutoriel `learnr` minimal avec trois questions et enregistrer les réponses.

### Tutoriel de test

Le tutoriel doit contenir :

- une question à choix multiple;
- un exercice de code simple;
- un exercice avec correction `gradethis`.

### Exemple souhaité

```text
Question 1 : calcul simple
Question 2 : utilisation de mean()
Question 3 : utilisation de dplyr::summarise()
```

### Problème central

Il faut décider comment déclencher `track_attempt()` lorsqu’une réponse est soumise.

Stratégies possibles :

1. Appel manuel dans le code de correction.
2. Fonction wrapper autour de la correction `gradethis`.
3. Injection Shiny.
4. Injection JavaScript.
5. Utilisation des mécanismes internes de stockage de `learnr`, si suffisamment accessibles.

### Livrables

- `inst/examples/minimal-learnr/`;
- un tutoriel `tutorial.Rmd`;
- une base SQLite générée;
- un script montrant les résultats;
- une note expliquant la stratégie retenue.

### Critère de réussite

Un étudiant fictif complète un mini tutoriel et ses réponses sont enregistrées.

## Étape 4. Identification simple des étudiant·es

### Objectif

Éviter que toutes les réponses soient anonymes.

### Approche MVP

Ajouter au début du tutoriel un champ d’identification.

Exemples :

```text
IDUL
Code étudiant
Adresse courriel institutionnelle
Identifiant de démonstration
```

### Options futures

- lien personnalisé;
- token individuel;
- authentification Google;
- authentification Microsoft;
- authentification institutionnelle;
- Posit Connect.

### Fonctions possibles

```r
set_student_id()
get_student_id()
validate_student_id()
```

### Livrables

- formulaire d’identification simple;
- validation minimale;
- stockage du `student_id`;
- documentation des limites de sécurité.

### Critère de réussite

Les réponses sont associées à un identifiant étudiant.

## Étape 5. Calcul des scores

### Objectif

Transformer les tentatives en notes exploitables.

### Questions à trancher

- Garde-t-on la dernière tentative?
- Garde-t-on la meilleure tentative?
- Garde-t-on la première tentative?
- Autorise-t-on une pondération par question?
- Comment traiter les questions non répondues?
- Comment traiter les réponses partielles?
- Comment traiter les tentatives multiples?

### Fonctions possibles

```r
compute_scores()
score_last_attempt()
score_best_attempt()
score_first_attempt()
gradebook()
```

### Exemple visé

```r
gradebook(db, tutorial_id = "module_02")
```

Résultat :

```text
student_id | tutorial_id | score | max_score | percent | completed
```

### Livrables

- moteur de scoring;
- tests unitaires;
- export des notes;
- documentation des règles.

### Critère de réussite

On peut produire une note finale par étudiant et par tutoriel.

## Étape 6. Export CSV et Moodle

### Objectif

Permettre à l’enseignant de récupérer les résultats facilement.

### Exports prioritaires

```r
export_results()
export_gradebook()
export_moodle_grades()
```

### Formats

1. Export complet des tentatives.
2. Export résumé par étudiant.
3. Export Moodle.
4. Export par question.
5. Export pour analyse pédagogique.

### Livrables

- fichiers CSV;
- documentation;
- exemple Moodle;
- tests sur les colonnes attendues.

### Critère de réussite

L’enseignant peut produire un fichier de notes importable dans Moodle.

## Étape 7. Tableau de bord enseignant

### Objectif

Créer une application Shiny pour consulter les résultats.

### Fonction principale

```r
run_dashboard(db_path = "learnrtrackr.sqlite")
```

### Vues prioritaires

#### Vue cours

- nombre d’étudiant·es;
- taux de complétion;
- score moyen;
- score médian;
- nombre de tentatives;
- questions les plus difficiles.

#### Vue étudiant

- progression;
- score;
- réponses;
- nombre d’essais;
- dernière activité.

#### Vue question

- taux de réussite;
- distribution des scores;
- réponses fréquentes;
- feedback fréquent;
- temps moyen si disponible.

### Livrables

- application Shiny minimale;
- filtres par cours, tutoriel, groupe et étudiant;
- export depuis le dashboard;
- documentation.

### Critère de réussite

Un enseignant peut ouvrir un tableau de bord et comprendre rapidement les résultats d’une cohorte.

## Étape 8. Déploiement serveur

### Objectif

Permettre une utilisation réelle dans un cours.

### Options

#### Option 1 : SQLite local

Usage :

- démonstration;
- petit groupe;
- tutoriel local.

Limites :

- concurrence limitée;
- difficile pour plusieurs étudiant·es simultanément;
- moins adapté à un vrai cours.

#### Option 2 : PostgreSQL

Usage :

- cours complet;
- plusieurs groupes;
- serveur Shiny;
- déploiement plus robuste.

#### Option 3 : Posit Connect

Usage :

- institution déjà équipée;
- authentification;
- suivi plus propre;
- gestion serveur facilitée.

#### Option 4 : Docker

Usage :

- déploiement reproductible;
- serveur indépendant;
- démonstration portable;
- documentation TI.

### Livrables

- support PostgreSQL;
- variables d’environnement;
- exemple Docker;
- guide de déploiement;
- guide de sécurité.

### Critère de réussite

Le système peut être utilisé par plusieurs étudiant·es dans un environnement contrôlé.

## Étape 9. Sécurité, confidentialité et éthique

### Objectif

Encadrer l’utilisation de données étudiantes.

### Points à traiter

- minimisation des données;
- choix des identifiants;
- consentement ou information;
- accès enseignant;
- conservation des données;
- suppression des données;
- stockage local ou serveur;
- export sécurisé;
- conformité avec les politiques institutionnelles.

### Principe important

Le système ne doit pas stocker plus de données que nécessaire.

### Livrables

- `privacy.md`;
- guide de bonnes pratiques;
- paramètres de rétention;
- fonction de suppression.

### Fonctions possibles

```r
delete_student_data()
anonymise_results()
pseudonymise_results()
```

### Critère de réussite

Le projet peut être présenté aux TI ou à un comité pédagogique sans inquiétude majeure.

## Étape 10. Analyse pédagogique avancée

### Objectif

Transformer les résultats en informations utiles pour améliorer l’enseignement.

### Analyses possibles

- questions les plus échouées;
- questions avec beaucoup de tentatives;
- questions abandonnées;
- erreurs fréquentes;
- progression par section;
- étudiants bloqués;
- comparaison entre groupes;
- comparaison entre cohortes.

### Fonctions possibles

```r
summarise_questions()
summarise_students()
detect_difficult_questions()
detect_stalled_students()
generate_teacher_report()
```

### Sorties possibles

- tableau;
- rapport HTML;
- rapport Quarto;
- résumé enseignant;
- recommandations pédagogiques.

### Critère de réussite

L’enseignant obtient des informations exploitables pour améliorer ses tutoriels.

## Étape 11. Module IA optionnel

### Objectif

Ajouter une couche d’analyse qualitative automatique.

### Utilisations possibles

- résumer les erreurs fréquentes;
- proposer des rétroactions;
- suggérer des reformulations;
- détecter les concepts mal compris;
- générer un rapport hebdomadaire.

### Principe

Le module IA doit rester optionnel. Le package doit fonctionner sans IA.

### Fonctions possibles

```r
generate_ai_summary()
suggest_feedback_improvements()
summarise_common_errors()
```

### Critère de réussite

L’IA apporte une valeur ajoutée sans devenir une dépendance obligatoire.

## Étape 12. Intégration avec tutorizeR

### Objectif

Faire communiquer `tutorizeR` et `learnrTrackR`.

### Vision

`tutorizeR` pourrait produire automatiquement des tutoriels déjà instrumentés pour le suivi.

### Exemple

```r
tutorizeR::convert_to_learnr(
  input = "module_02.qmd",
  output = "tutorial.Rmd",
  tracking = TRUE,
  tracking_package = "learnrTrackR"
)
```

### Livrables

- convention commune;
- exemple intégré;
- vignette conjointe;
- démonstration complète.

### Critère de réussite

Un document pédagogique peut être converti en tutoriel suivi et exportable.

## Étape 13. Documentation, tests et publication

### Objectif

Rendre le package utilisable par d’autres.

### Documentation

- README;
- vignette de démarrage;
- vignette enseignant;
- vignette développeur;
- guide de déploiement;
- guide Moodle;
- guide confidentialité;
- site pkgdown.

### Tests

- tests de schéma;
- tests d’insertion;
- tests d’export;
- tests de scoring;
- tests de dashboard si possible;
- tests de compatibilité.

### Publication

Étapes possibles :

1. GitHub public.
2. Site pkgdown.
3. Version 0.1.0.
4. Utilisation pilote.
5. Préparation JOSE.
6. Soumission éventuelle à CRAN si le package devient stable.

## 8. Feuille de route par version

## Version 0.0.1 : squelette

Objectif :

```text
Créer le package et sa structure.
```

Livrables :

- DESCRIPTION;
- NAMESPACE;
- fonctions vides;
- README;
- tests initiaux;
- exemple minimal.

## Version 0.1.0 : base SQLite

Objectif :

```text
Pouvoir enregistrer des tentatives simulées.
```

Fonctions :

```r
init_tracking_db()
track_attempt()
get_attempts()
export_results()
```

## Version 0.2.0 : mini tutoriel learnr

Objectif :

```text
Connecter un tutoriel learnr minimal.
```

Livrables :

- tutoriel exemple;
- stockage des réponses;
- stockage des scores;
- documentation.

## Version 0.3.0 : version pilote contrôlée

Objectif :

```text
Préparer un pilote contrôlé documenté.
```

Livrables :

- exports Moodle et Canvas;
- tableau de bord local;
- support PostgreSQL optionnel;
- protocole de pilote;
- gabarit de bilan post-pilote;
- métadonnées de citation;
- brouillon de papier descriptif.

## Version 0.4.0 : durcissement opérationnel

Objectif :

```text
Réduire les risques avant un déploiement contrôlé avec de vrais groupes.
```

Ajouts prioritaires :

- contrôles de doublons dans les identifiants étudiants;
- contrôles de questions manquantes ou non attendues;
- diagnostics avant export LMS;
- guide de déploiement Posit Connect ou Shiny Server;
- procédure de rétention et suppression plus explicite.

## Version 0.5.0 : retour de pilote

Objectif :

```text
Intégrer les observations d'un petit pilote réel ou semi-réel.
```

Ajouts prioritaires :

- bilan post-pilote;
- corrections issues du pilote;
- documentation des limites observées;
- révision du papier avec preuves descriptives;
- préparation d'une release archivée avec DOI.

## Version 0.6.0 : publication logicielle

Objectif :

```text
Préparer une soumission logicielle descriptive.
```

Ajouts :

- release Zenodo;
- DOI dans les fichiers de citation;
- papier révisé;
- guide enseignant stabilisé;
- limites et prérequis clairement documentés.

## Version 0.7.0 : extensions pédagogiques

Objectif :

```text
Élargir les analyses pédagogiques sans prétendre à des effets non mesurés.
```

Fonctions :

```r
summarise_questions()
detect_difficult_questions()
generate_teacher_report()
```

Ces fonctions existent déjà en forme initiale. Cette étape viserait surtout
leur consolidation, leur documentation et leur validation sur données pilotes.

## Version 1.0.0 : version stable

Objectif :

```text
Version prête pour utilisation externe et article JOSE.
```

Exigences :

- documentation complète;
- tests;
- pkgdown;
- exemples reproductibles;
- guide de confidentialité;
- cas d’utilisation réel ou pilote documenté.

## 9. Risques techniques

## 9.1 Interception des réponses

Le principal risque est que `learnr` ou `gradethis` ne permette pas facilement d’intercepter proprement toutes les informations nécessaires.

Stratégie :

- commencer par un prototype manuel;
- documenter les limites;
- éviter de dépendre d’éléments internes trop fragiles;
- isoler les points d’intégration dans peu de fonctions.

## 9.2 Compatibilité avec les versions futures

Si le package dépend de comportements internes de `learnr`, il pourrait casser.

Stratégie :

- tests de compatibilité;
- CI sur plusieurs versions de R;
- documentation claire des versions supportées.

## 9.3 Concurrence d’écriture

SQLite peut être limité si plusieurs étudiant·es écrivent en même temps.

Stratégie :

- SQLite pour MVP;
- PostgreSQL pour usage réel;
- avertissements dans la documentation.

## 9.4 Données étudiantes

Le stockage de réponses étudiantes pose des enjeux de confidentialité.

Stratégie :

- minimisation;
- pseudonymisation possible;
- documentation;
- suppression des données;
- choix explicite du backend.

## 10. Critères de succès globaux

Le projet sera réussi si un enseignant peut :

1. créer ou utiliser un tutoriel `learnr`;
2. activer le suivi avec une configuration simple;
3. demander aux étudiant·es de compléter le tutoriel;
4. récupérer automatiquement les réponses;
5. voir les scores;
6. exporter les notes;
7. identifier les questions problématiques;
8. réutiliser le système dans un autre cours.

## 11. Première étape à réaliser maintenant

La première étape concrète est de créer un dépôt et un package R minimal qui permet de stocker des tentatives simulées dans SQLite.

Il ne faut pas encore essayer d’intégrer complètement `learnr`.

La première étape doit uniquement valider :

```text
Peut-on créer une base propre, insérer des tentatives, relire les données et exporter un tableau?
```

Cela donne une base solide avant de s’attaquer à l’intégration avec `learnr` et `gradethis`.
