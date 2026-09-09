# radar — ein routender Omnigent-Orchestrator

`radar` klassifiziert eine Anfrage, schlägt die **günstigste passende Lane** vor
und delegiert die Schritte an dedizierte Claude-Sub-Agents. Er schreibt keinen
Code, reviewt nicht und **verifiziert nichts** — Verifikation ist ein Schritt,
den du dazunimmst, nicht etwas, das der Orchestrator hinter deinem Rücken tut.

```bash
omnigent run agents/radar
```

## Warum nicht der Vorgänger

Das Vorgänger-Bundle (`alfred`) erzwang eine feste Pipeline: Idee → Spec →
Approval → Ticket → Code → Test → Review → Docs → PR. Drei Dinge machten das für
kleine Aufgaben unbenutzbar:

1. **Der Workflow war eine State Machine.** *„The next action is the next stage
   whose DoD is unmet. Never skip."* Es gab keinen Einstieg bei Stage 4.
2. **Die Starrheit saß auf Mechanismus-Ebene.** Eine CEL-Policy eskalierte jeden
   Code-Dispatch ohne `SPEC-APPROVED` und Ticket. Kein Prompt konnte das lockern.
3. **Es gab nur eine Task-Form.** Ein Typo-Fix musste durch dieselbe Form wie ein
   Epic.

`radar` dreht das um: **jeder Schritt ist ein Einstiegspunkt, jeder Schritt ist
überspringbar.** Eine Lane ist ein Vorschlag, keine Voraussetzung. Es gibt keine
Workflow-Policy — nur Sicherheits-Guardrails.

## Lanes

| Lane | Wann | Kette |
|---|---|---|
| **0 · chat** | Frage, kein Änderungswunsch | antworten, ggf. ein `explore` |
| **1 · quick** | kleine, benannte Änderung, kein Ticket | `implement` → `wrap?` |
| **2 · ticket** | Ticket-Referenz vorhanden | `implement` → `review` → `wrap` |
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
| `onboard` | 4× `explorer` parallel | `.omnigent/project/*` |
| `explore` | `explorer` | Findings |
| `grill` | radar | geschärftes Problem |
| `spec` | radar | `docs/specs/<slug>.md`, `AC-1…n` |
| `tickets` | `ticketer` | Issues in Dependency-Reihenfolge |
| `implement` | `coder` | Branch, Diff, Gates gelaufen |
| `design` | `designer` (opt-in) | Presentation-only Diff |
| `review` | `reviewer` | Findings vs. AC, Gates nachgefahren |
| `wrap` | `scribe` | Commit-Message, MR/PR offen |
| `learn` | radar | eine Zeile in `.omnigent/learnings.md` |

## Worker

| Worker | Modell | darf pushen | Read-only |
|---|---|---|---|
| `explorer` | sonnet | – | faktisch (schreibt genau eine Datei) |
| `coder` | sonnet | – | – |
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
    INDEX.md commands.md architecture.md conventions.md domain.md vcs.md
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
