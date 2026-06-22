# GooseDesigns — Daily UI Design Inspiration from Trending GitHub Repos

![GooseDesigns — a daily montage of hero and landing-page UI design mockups for trending GitHub repositories](assets/banner.png)

![Updated daily](https://img.shields.io/badge/updated-daily-5eead4?style=flat-square) ![45 mocks](https://img.shields.io/badge/mocks-45-1f6feb?style=flat-square) ![15 days](https://img.shields.io/badge/days-15-30363d?style=flat-square) [![Live site](https://img.shields.io/badge/live-GitHub%20Pages-2ea043?style=flat-square)](https://newgoosefactory.github.io/GooseDesigns/) ![License MIT](https://img.shields.io/badge/license-MIT-2ea043?style=flat-square)

**A fresh set of landing-page and hero-section design mockups every morning.** GooseDesigns is an automated design-practice gallery: each day it reads [GitHub Trending](https://github.com/trending), picks the most interesting repositories — AI, autonomous agents, developer tools, local LLMs, and PKM — and reimagines each project's **hero / landing-page UI** in a rotating visual style. Real product copy, accessible contrast, intentional motion, and no generic AI-gradient slop.

Use it for **UI inspiration, web-design examples, landing-page ideas, and front-end reference** — 45 mockups across 15 days and 7 style families, updated daily. See the **[full design catalog](CATALOG.md)** or the **[live gallery](https://newgoosefactory.github.io/GooseDesigns/)**.

## Browse

- **[Full catalog](CATALOG.md)** — every mock in one searchable table
- **By style:** [blueprint](styles/blueprint.md) · [brutalist](styles/brutalist.md) · [data-viz](styles/data-viz.md) · [editorial](styles/editorial.md) · [hud](styles/hud.md) · [swiss](styles/swiss.md) · [terminal-dark](styles/terminal-dark.md)
- **[Design Taste Ledger](ledger.md)** · **[Concept: Design Taste](concept.md)**
- **[Design system & discoverability spec](DESIGN.md)** — palette, type scale, the four style families, and how this repo is built for reach

## Latest — Monday, June 22

<table><tr>
<td align="center" width="33%"><a href="days/2026-06-22/"><img src="days/2026-06-22/01-OpenMontage.png" width="320" alt="calesthio/OpenMontage"></a><br><sub><b>calesthio/OpenMontage</b><br>brutalist</sub></td>
<td align="center" width="33%"><a href="days/2026-06-22/"><img src="days/2026-06-22/02-worldmonitor.png" width="320" alt="koala73/worldmonitor"></a><br><sub><b>koala73/worldmonitor</b><br>data-viz</sub></td>
<td align="center" width="33%"><a href="days/2026-06-22/"><img src="days/2026-06-22/03-penpot.png" width="320" alt="penpot/penpot"></a><br><sub><b>penpot/penpot</b><br>swiss</sub></td>
</tr></table>

[See the full day →](days/2026-06-22/)

## All reps

| Date | Day | Mocks | Styles | Page |
|------|-----|-------|--------|------|
| 2026-06-22 | Monday | 3 | brutalist, data-viz, swiss | [open](days/2026-06-22/) |
| 2026-06-21 | Sunday | 3 | blueprint | [open](days/2026-06-21/) |
| 2026-06-20 | Saturday | 3 | hud | [open](days/2026-06-20/) |
| 2026-06-19 | Friday | 3 | editorial | [open](days/2026-06-19/) |
| 2026-06-18 | Thursday | 3 | terminal-dark | [open](days/2026-06-18/) |
| 2026-06-17 | Wednesday | 3 | hud | [open](days/2026-06-17/) |
| 2026-06-16 | Tuesday | 3 | editorial | [open](days/2026-06-16/) |
| 2026-06-15 | Monday | 3 | terminal-dark | [open](days/2026-06-15/) |
| 2026-06-14 | Sunday | 3 | hud, editorial, terminal-dark | [open](days/2026-06-14/) |
| 2026-06-13 | Saturday | 3 | hud | [open](days/2026-06-13/) |
| 2026-06-12 | Friday | 3 | editorial | [open](days/2026-06-12/) |
| 2026-06-11 | Thursday | 3 | terminal-dark | [open](days/2026-06-11/) |
| 2026-06-10 | Wednesday | 3 | hud | [open](days/2026-06-10/) |
| 2026-06-09 | Tuesday | 3 | editorial | [open](days/2026-06-09/) |
| 2026-06-08 | Monday | 3 | terminal-dark | [open](days/2026-06-08/) |

## Style rotation

| Family | When | Feel |
|--------|------|------|
| terminal-dark | Mon / Thu | Near-black dev-tool; one electric accent (Linear / Vercel / Raycast) |
| editorial | Tue / Fri | Light, calm, serif headline + clean sans, generous whitespace (Stripe-essay) |
| hud | Wed / Sat | Top Gun aviation-instrument; amber/green readouts, subtle grid, restrained |
| blueprint | designer's choice | Architectural schematic; drafting grid, technical annotations |

## How it works

A scheduled `Goose` automation runs daily at 6:00 AM CT. It builds the trending briefing, writes 2—3 self-contained HTML hero mocks in the day's style, screenshots each, and captures everything to an Obsidian vault. `tools/Build-GooseDesigns.ps1` then regenerates this repo (catalog, day pages, style indexes, homepage) from those sources and pushes. The build is idempotent — re-running never duplicates.

## Search tips

- Press <kbd>/</kbd> for repo search, or <kbd>t</kbd> for the file finder.
- Code-search keywords land in [CATALOG.md](CATALOG.md): style names (`blueprint`, `hud`), repo names, and the *idea tested* per mock.
- Browse by visual family under [styles/](styles/).

<sub>Generated by `tools/Build-GooseDesigns.ps1` · sources: GitHub Trending + an Obsidian design-practice vault.</sub>
