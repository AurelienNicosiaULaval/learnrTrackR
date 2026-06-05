# Checklist de publication learnrTrackR

Cette checklist prépare une publication GitHub de `learnrTrackR`. Elle ne
suppose pas qu'un remote GitHub existe déjà.

## Vérifications locales

Depuis la racine du package:

```r
devtools::document()
devtools::test()
rcmdcheck::rcmdcheck(args = "--no-manual")
```

Le résultat attendu avant publication est:

```text
0 errors | 0 warnings | 0 notes
```

Vérifier aussi les fichiers non suivis:

```sh
git status --short
```

## Version

Avant de créer un tag:

1. Vérifier que `DESCRIPTION` contient la version à publier.
2. Vérifier que `NEWS.md` contient une section pour la version à publier.
3. Vérifier que les exemples installés sous `inst/examples/` sont à jour.
4. Vérifier que `privacy.md` et les vignettes sont cohérents.
5. Vérifier que les tests PostgreSQL réels sont sautés ou exécutés avec une
   base jetable.

## GitHub

Créer le dépôt GitHub, puis ajouter le remote avec SSH:

```sh
git remote add origin git@github.com:AurelienNicosiaULaval/learnrTrackR.git
git push -u origin main
```

Créer un tag local et le pousser, en remplaçant `vX.Y.Z` par la version
publiée:

```sh
git tag -a vX.Y.Z -m "learnrTrackR X.Y.Z"
git push origin vX.Y.Z
```

## GitHub Actions

Deux workflows sont fournis:

- `.github/workflows/R-CMD-check.yaml`;
- `.github/workflows/pkgdown.yaml`.

Le workflow `R-CMD-check` teste le package sur Ubuntu, macOS et Windows avec R
release. Le workflow `pkgdown` construit le site et le publie avec GitHub Pages.

Pour le site pkgdown, configurer GitHub Pages avec la source `GitHub Actions`
dans les paramètres du dépôt.

## Site pkgdown local

Pour vérifier le site avant publication:

```r
pkgdown::build_site(new_process = FALSE, install = TRUE)
```

Le dossier `docs/` est ignoré localement par Git.

## Données et secrets

Ne jamais publier:

- fichiers `.env`;
- dumps SQLite ou PostgreSQL contenant des données étudiantes;
- exports CSV avec identifiants étudiants;
- clés de correspondance issues de `pseudonymise_results()`;
- jetons de dashboard ou mots de passe PostgreSQL.

## Tests PostgreSQL réels

Le test PostgreSQL d'intégration est optionnel. Pour l'exécuter:

```sh
export LEARNRTRACKR_TEST_POSTGRES_DSN="postgresql://learnrtrackr:password@127.0.0.1:5432/learnrtrackr"
Rscript -e 'devtools::test(filter = "db")'
```

Utiliser une base de test jetable.

## Sources

- r-lib. Consulté le 2026-06-04. r-lib/actions.
  <https://github.com/r-lib/actions>
- pkgdown. Consulté le 2026-06-04. Deploy a site.
  <https://pkgdown.r-lib.org/reference/deploy_to_branch.html>
- GitHub Docs. Consulté le 2026-06-04. Configuring a publishing source for
  your GitHub Pages site.
  <https://docs.github.com/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site>
