# Runbook — Aligner un repo existant sur la gouvernance itshaker + contrat Hermes

**Périmètre :** tout repo `lowcodai/*` que vous voulez faire correspondre à la structure
`itshaker-copilot-governance` (instructions/hooks/agents Copilot) et au contrat de
continuité Hermes (`.hermes.md` + `docs/operations/{CURRENT,HANDOFF,ACTIVITY}.md`).
**Public :** Arcane (exécution) + Capitaine (revue/validation).
**Origine :** appliqué réellement le 2026-09-14 sur 6 repos (governance, bootstrap, 4
templates, dgx-spark-V2, llmwiki) + HermesVPS2 lui-même. Voir `HermesVPS2/BACKLOG.md`
ticket `#6` et `CHANGELOG.md` (2026-09-14) pour l'historique des commits de référence.

---

## Étape 0 — Prérequis d'agencement des dossiers

`sync-governance.sh` résout `itshaker-copilot-governance` par **chemin relatif fixe**
(`${BOOTSTRAP_DIR}/../itshaker-copilot-governance`) — **piège connu :** `docs/usage.md`
documente un flag `--governance-dir`, mais il n'existe pas dans le script réel (vérifié
2026-09-14 par grep sur `scripts/sync-governance.sh`). Ne pas s'y fier tant que la doc
n'est pas corrigée ou le flag ajouté. Cloner donc les deux repos **côte à côte** :

```bash
mkdir -p /opt/data/workspace/itshaker-align && cd /opt/data/workspace/itshaker-align
gh repo clone lowcodai/itshaker-copilot-governance
gh repo clone lowcodai/itshaker-bootstrap
gh repo clone lowcodai/<le-repo-a-aligner>
```

---

## Étape 1 — Identifier le type de template le plus proche

`base | infra | ai | app` — choisir celui qui correspond au repo cible (peu importe s'il
n'a pas été créé avec `new-project.sh` à l'origine : `--extend-only` n'ajoute que ce qui
manque, jamais n'écrase).

---

## Étape 2 — Dry-run obligatoire avant toute écriture

```bash
cd itshaker-bootstrap
DRY_RUN=true ./scripts/sync-governance.sh \
  --type <base|infra|ai|app> \
  --dest ../<le-repo-a-aligner> \
  --extend-only --verbose
```

Lire la sortie : elle doit lister ce qui **serait** créé (`instructions/`, `hooks/`,
`agents/`, `.hermes.md`, `docs/operations/{CURRENT,HANDOFF,ACTIVITY}.md`, `templates/`)
sans rien écrire. Si des fichiers `docs/operations/*.md` du repo cible existent déjà et
sont datés/en usage, vérifier qu'ils apparaissent en `[SKIP]` et non en `[CREATE]`.

---

## Étape 2bis — Vérifier la méthodologie PRD/ADR dans le dry-run

Dans la sortie de l'Étape 2, confirmer la présence de ces lignes (nouvelles depuis l'ajout de
`sync_methodology()`) :

```text
[CREATE] docs/prd/README.md        (ou [SKIP] si le repo cible en a déjà un)
[CREATE] docs/adr/README.md        (ou [SKIP] — ex: itshaker-dgx-spark-V2 en a déjà un réel)
[CREATE] docs/methodology/PRD-ADR-PLAN-RUNBOOK-WORKFLOW.md
[CREATE] .github/agents/prd-generator.agent.md
```

Si un repo cible a déjà un `docs/adr/README.md` réel et daté (ex: `itshaker-dgx-spark-V2`), il
**doit** apparaître en `[SKIP]`, jamais en `[CREATE]` — sinon `--extend-only` a régressé.

---

## Étape 3 — Exécution réelle

```bash
./scripts/sync-governance.sh \
  --type <base|infra|ai|app> \
  --dest ../<le-repo-a-aligner> \
  --extend-only
```

`--extend-only` est la garantie testée d'idempotence (vérifiée le 2026-09-14 : modification
manuelle de `CURRENT.md` + re-run → fichier préservé, `[SKIP]` loggé). Ne jamais lancer sans
`--extend-only` sur un repo qui a déjà du contenu réel dans `docs/operations/`.

---

## Étape 4 — Vérifier le résultat avant de committer

```bash
cd ../<le-repo-a-aligner>
git status --short          # doit ne montrer QUE des fichiers nouveaux (A/??), aucun M
                             # sur un fichier docs/operations/*.md déjà daté/en usage
ls docs/operations/          # CURRENT.md HANDOFF.md ACTIVITY.md doivent être présents
grep -n "^| \`" .hermes.md   # la table modèle → seuils de contexte doit apparaître
                             # (Qwen3.8-27B-NVFP4 / Sonnet 5 / GPT-5.6 Sol)
```

Si un fichier `docs/operations/*.md` daté existant apparaît en `M` (modifié) plutôt qu'en
`clean`/`??` : **arrêter, ne pas committer**, investiguer — c'est le signe que
`--extend-only` n'a pas été respecté ou qu'un bug de régression est réapparu.

---

## Étape 5 — Commit + push, puis vérification distante réelle

```bash
git add .hermes.md docs/operations/ instructions/ hooks/ agents/ 2>/dev/null
git commit -m "feat(hermes): contrat de continuité Hermes + gouvernance Copilot (aligné sur itshaker-copilot-governance)"
git push origin main
```

**Ne jamais déclarer "commité et pushé" sans vérifier le SHA distant** (leçon du
2026-09-14, question du Capitaine sur ce point précis) :

```bash
local_head=$(git rev-parse --short HEAD)
git fetch origin main -q
remote_head=$(git rev-parse --short origin/main)
[ "$local_head" = "$remote_head" ] && echo "OK: $local_head" || echo "MISMATCH local=$local_head remote=$remote_head"
git status --short   # doit être vide (working tree clean)
```

---

## Étape 6 — Documenter dans HermesVPS2

Ajouter une entrée `CHANGELOG.md` (format `[YYYY-MM-DD] feat — ...`) référençant le SHA du
commit produit à l'Étape 5, et mettre à jour le ticket `BACKLOG.md` correspondant (ou en
ouvrir un nouveau si c'est un repo hors du lot initial du ticket `#6`).

---

## Checklist de clôture

- [ ] Dry-run exécuté et lu avant l'exécution réelle
- [ ] `--extend-only` utilisé (jamais de run nu sur un repo avec contenu existant)
- [ ] `git status --short` propre après sync — aucun fichier daté écrasé
- [ ] Table modèle → seuils de contexte présente dans `.hermes.md`
- [ ] Commit + push effectués
- [ ] SHA local == SHA `origin/main` vérifié par `git fetch` (pas supposé)
- [ ] `HermesVPS2/CHANGELOG.md` et `BACKLOG.md` mis à jour avec le SHA réel

## Pièges connus

- `docs/usage.md` documente `--governance-dir` : **n'existe pas** dans
  `sync-governance.sh` au 2026-09-14. Chemin relatif fixe uniquement. Signalé, pas corrigé
  (hors scope de cet alignement) — à corriger un jour, soit en implémentant le flag, soit
  en retirant la mention de la doc.
- Ne jamais lancer `sync-governance.sh` sans `--extend-only` sur un repo qui contient déjà
  des notes actives dans `docs/operations/` — sans ce flag le comportement par défaut n'a
  pas été validé pour la préservation de contenu existant.
- La table modèle → seuils de contexte (`.hermes.md`) est à réviser si les fournisseurs
  changent leurs fenêtres de contexte silencieusement, ou si le Capitaine change ses 3
  modèles de référence (Qwen3.8-27B-NVFP4 défaut / Sonnet 5 / GPT-5.6 Sol raisonnement lourd).
