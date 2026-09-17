# radar — ein routender Omnigent-Orchestrator

`radar` klassifiziert eine Anfrage, schlägt die **günstigste passende Lane** vor
und delegiert die Schritte an dedizierte Claude-Sub-Agents. Er schreibt keinen
Code, reviewt nicht und **verifiziert nichts** — Verifikation ist ein Schritt,
den du dazunimmst, nicht etwas, das der Orchestrator hinter deinem Rücken tut.

## Installieren

```bash
git clone git@github.com:ifahrentholz/omnigent-radar.git
cd omnigent-radar && ./install.sh
```

Das Script prüft die Voraussetzungen (git, `omnigent`, ein konfigurierter
Claude-Provider, `gh`/`glab`) und legt einen Symlink `radar` nach
`~/.local/bin`. Anderes Ziel mit `--dir ~/bin`, rückgängig mit `--uninstall`.

**Es fasst deine Shell-Config nicht an.** Ein Symlink in einem PATH-Verzeichnis
wirkt in jeder Shell, ist eine Zeile zum Rückgängigmachen und kann keine
Login-Shell zerschießen — anders als ein misslungener rc-Edit. Voraussetzung ist
nur, dass das Zielverzeichnis auf dem PATH liegt; das Script sagt dir, wenn
nicht.

Omnigent selbst wird **nicht** mitinstalliert — siehe https://omnigent.ai/.

## Starten

```bash
cd <dein-projekt>
radar                    # interaktive Session
radar -p "frage"         # headless: ein Request, dann Ende
```

radar läuft im aktuellen Working Directory, nicht in dem des Bundles, und setzt
`--log` von selbst (außer bei `-p`, wo Omnigent es ablehnt).

**Du schreibst zuerst.** Omnigent kennt keinen agent-initiierten ersten Turn:
mit `-p` läuft es einmal headless durch und beendet sich (`cli.py`, `run_chat` —
„runs one-shot and exits when `initial_message` is set"). Vorbelegen ginge nur
mit `--resume`/`--continue`, was den Kontext der alten Konversation mitschleppt.
radar führt seine **erste Antwort** deshalb mit dem Projektstatus an, statt ihn
vorweg zu senden.

### Windows

Derzeit nicht unterstützt, und ein PowerShell-Launcher wäre nicht der schwierige
Teil: die Skills selbst fahren POSIX-Shell-Kommandos (`git log … | sort | uniq`,
`grep`, `curl`), und radars `terminals:`-Block startet `bash`. Ein `.ps1` würde
also starten und beim ersten `onboard` scheitern. Für Windows-Kolleg:innen ist
**WSL** der pragmatische Weg — dort läuft das Bundle unverändert.

## Lanes

| Lane | Wann | Kette |
|---|---|---|
| **0 · chat** | Frage, kein Änderungswunsch | antworten, ggf. ein `explore` |
| **1 · quick** | kleine, benannte Änderung, kein Ticket | `implement` → `deliver?` |
| **2 · ticket** | Ticket-Referenz vorhanden | `implement` → `review` → `deliver` |
| **3 · feature** | neue Fähigkeit, Scope offen | `grill` → `spec` → `tickets` → pro Ticket Lane 2 |

Bei Zweifel wird die **günstigere** Lane vorgeschlagen. Hochstufen kostet dich
ein Wort; unnötige Zeremonie kostet eine Spec und zwanzig Minuten.

Nach jedem Schritt: eine Zeile Ergebnis, eine Zeile Vorschlag, Stopp.
`[⏎ ja / nein / …]` — blankes Enter ist immer eine gültige Antwort. Wer
durchziehen will, sagt „mach durch bis MR"; dann hält radar nur noch an echten
Entscheidungen.

## Schritte

| Schritt | Wer | Ergebnis |
|---|---|---|
| `onboard` | radar | `.omnigent/project/vcs.md` |
| `explore` | `explorer` | Findings |
| `grill` | radar | geschärftes Problem |
| `spec` | radar | `docs/specs/<slug>.md`, `AC-1…n` |
| `tickets` | `ticketer` | Issues in Dependency-Reihenfolge |
| `implement` | `coder` | Branch, Diff, Gates gelaufen |
| `design` | `designer` (opt-in) | Presentation-only Diff |
| `review` | `reviewer` | Findings vs. AC, Gates nachgefahren |
| `deliver` | `scribe` | Commit, Push, MR/PR offen |
| `learn` | radar | eine Zeile in `.omnigent/learnings.md` |

## Worker

| Worker | Modell | darf pushen | Read-only |
|---|---|---|---|
| `explorer` | sonnet | – | faktisch (schreibt genau eine Datei) |
| `coder` | **opus [1m]** | – | – |
| `reviewer` | **opus** | – | ja (`read_only_os`) |
| `ticketer` | sonnet | – | – |
| `scribe` | sonnet | **ja** | – |
| `designer` | sonnet | – | – |

Nur `scribe` darf pushen — strukturell, nicht nur per Prompt. Der `reviewer`
läuft bewusst auf einem anderen Tier als der `coder`: gleicher Vendor, aber ein
anderes Fehlerprofil, und Review ist die eine Stelle, wo das lohnt.

## Was im Zielprojekt entsteht

```
.omnigent/
  project/         # committen — Teamwissen
    vcs.md         # nur das: Tracker, CLI, Branch-/Commit-Konvention, Labels
  learnings.md     # committen — Regeln aus vergangenen Sessions, max. 40 Zeilen
  state.json       # committen — nur laufende Lane-3-Features
  runs/            # gitignoren — Worker-Reports
```

Ins Zielprojekt gehört dazu:

```gitignore
.omnigent/runs/
```

**Das Bundle ist die Methode, `.omnigent/` ist das Wissen.** Die Methode ist
projektübergreifend und lebt hier; das Wissen ist projektspezifisch und lebt
dort.

## Die zwei Kostenhebel

**Der Return-Block** in jeder Dispatch-Brief (siehe `skills/lanes/SKILL.md` §4):
Worker schreiben ihren vollen Report nach `.omnigent/runs/<id>/report.md` und
geben radar acht Zeilen Struktur zurück. Ohne das trägt der Orchestrator das
komplette Reasoning jedes Workers für den Rest der Session mit — das kostet mehr
als jede Modellwahl.

**`skills: none` überall.** Nichts wird vom Host entdeckt; jeder Skill liegt im
Bundle des Agents, der ihn ausführt. Sonst wird die komplette Host-Skill-Liste in
jeden einzelnen Turn injiziert.

## Selbstverbesserung

Zwei Ebenen, und die Unterscheidung ist der Punkt:

- **Projektregel** → `.omnigent/learnings.md` im Zielrepo. Etwas über *diesen*
  Codebase.
- **Bundle-Änderung** → ein Prompt- oder Skill-Edit hier, committet. Etwas über
  *die Methode*.

Nur das Zweite ist echte Selbstverbesserung. Eine Methodenschwäche in eine
Projektdatei zu schreiben behebt sie in einem Repo und lässt sie in allen anderen
wiederkehren. Details in `skills/learn/SKILL.md`.

## Struktur

```
bin/radar                        # Launcher (setzt die erste Nachricht ab)
agents/radar/
  config.yaml                    # Orchestrator
  skills/                        # radars eigene, interaktive Skills
    lanes/                       #   ← das Routing-Verfahren, Kern des Bundles
    onboard/  learn/
    grilling/  grill-me/  grill-with-docs/  to-spec/  domain-modeling/
  agents/<worker>/
    config.yaml
    skills/                      # gebündelt beim Worker, der sie ausführt
```
