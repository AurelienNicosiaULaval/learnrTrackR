# Confidentialité et gestion des données

Ce document décrit les pratiques minimales recommandées pour utiliser
`learnrTrackR` avec des données étudiantes. Il ne constitue pas un avis
juridique. Les règles applicables dépendent du contexte institutionnel, du type
de cours, des politiques de l'Université Laval et des lois en vigueur.

## Données stockées par défaut

Le schéma actuel peut stocker les éléments suivants:

- identifiant étudiant;
- libellé étudiant;
- courriel;
- groupe;
- cours;
- tutoriel;
- question;
- réponse soumise;
- statut de correction;
- score;
- rétroaction;
- horodatage.

Ces informations peuvent être des renseignements personnels lorsqu'elles
permettent d'identifier une personne directement ou indirectement.

## Principes pratiques

1. Ne collecter que les identifiants nécessaires au suivi pédagogique.
2. Éviter de stocker des noms complets si un identifiant institutionnel suffit.
3. Éviter de stocker des courriels dans les exports utilisés pour l'analyse.
4. Séparer les exports pseudonymisés de leur clé de correspondance.
5. Restreindre l'accès aux bases SQLite, bases PostgreSQL et fichiers CSV.
6. Définir une durée de conservation avant le début du cours.
7. Supprimer ou archiver les données selon les règles institutionnelles.
8. Tester les exports avec des données fictives avant une vraie cohorte.

## Suppression d'un étudiant

`delete_student_data()` supprime les tentatives et les sessions associées à un
identifiant étudiant. Par défaut, la ligne du registre étudiant est aussi
supprimée.

```r
deleted <- delete_student_data(
  con,
  student_id = "student_001"
)

deleted
```

Pour conserver l'inscription dans le registre local:

```r
delete_student_data(
  con,
  student_id = "student_001",
  delete_student = FALSE
)
```

La suppression ne retire pas les métadonnées de cours, de tutoriels ou de
questions, car ces informations ne sont pas propres à une seule personne.

## Pseudonymisation

`pseudonymise_results()` remplace les identifiants étudiants par des pseudonymes
séquentiels et retourne une clé séparée.

```r
exported <- tracking_export_data(
  con,
  tutorial_id = "module_01"
)

pseudo <- pseudonymise_results(exported)

pseudo$data
pseudo$key
```

La clé demeure identifiante. Elle doit être conservée séparément, avec un accès
restreint. Pour garder la même correspondance entre plusieurs exports, réutiliser
la clé:

```r
pseudo_next <- pseudonymise_results(
  exported_next,
  key = pseudo$key
)
```

## Anonymisation pratique

`anonymise_results()` retire des colonnes identifiantes directes:

```r
anonymous <- anonymise_results(exported)
```

Par défaut, les colonnes `student_id`, `student_label` et `email` sont retirées.
Cette opération est une aide de minimisation des données. Elle ne garantit pas
que les résultats sont anonymes au sens juridique ou statistique. Les réponses
libres, petits groupes, horodatages ou combinaisons rares peuvent encore
permettre une réidentification.

Pour retirer aussi le groupe:

```r
anonymous <- anonymise_results(
  exported,
  drop_columns = c("student_id", "student_label", "email", "group_id")
)
```

## Déploiement PostgreSQL

Pour un déploiement serveur, utiliser une base dédiée, un utilisateur dédié et
un mot de passe fort. Ne pas committer de fichier `.env`, de dump de base de
données ou d'exports contenant des données étudiantes.

L'exemple Docker Compose fourni dans `inst/examples/postgres-docker/` est un
gabarit local de répétition. Il ne remplace pas une configuration TI complète.

## Limites actuelles

- Pas d'authentification institutionnelle.
- Pas de contrôle de rôle enseignant, auxiliaire ou étudiant.
- Pas de chiffrement applicatif des réponses.
- Pas de journal d'audit complet.
- Pas de politique de rétention automatisée.
- Le dashboard interactif lancé avec `run_dashboard()` reste centré sur un
  fichier SQLite.

## Sources

- Commission d'accès à l'information du Québec. Consulté le 2026-06-04.
  Conservation et destruction des renseignements personnels.
  <https://www.cai.gouv.qc.ca/protection-renseignements-personnels/information-ministeres-et-organismes-publics/conservation-destruction-renseignements-personnels>
- Commission d'accès à l'information du Québec. Consulté le 2026-06-04.
  Conservation et destruction des renseignements personnels pour les entreprises
  privées.
  <https://www.cai.gouv.qc.ca/protection-renseignements-personnels/information-entreprises-privees/conservation-destruction-renseignements-personnels>
- Gouvernement du Québec. Consulté le 2026-06-04. Anonymisation.
  <https://www.quebec.ca/gouvernement/travailler-gouvernement/normes-gouvernance-pratiques-internes/protection-des-renseignements-personnels/anonymisation>
- Office of the Privacy Commissioner of Canada. Consulté le 2026-06-04.
  Office of the Privacy Commissioner of Canada.
  <https://www.priv.gc.ca/en>
