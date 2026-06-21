# DESIGN.md — Design system & discoverability

This is the design spec for **GooseDesigns**, a daily gallery of landing-page and hero-section UI mockups for trending GitHub repositories. It documents two things: the **visual design system** every mockup follows, and the **discoverability strategy** (aligned with Google's SEO guidance) that makes this repo easy to find.

---

## 1. Design principles

The work follows a small set of rules, applied every day. The goal is craft, not decoration.

- **Restraint over decoration.** One idea per screen, one accent per mock. If an element doesn't earn its place, it's cut.
- **Real type scale.** A deliberate modular scale (not arbitrary sizes). Big, confident headlines; calm body text; generous line-height.
- **Accessible contrast.** Text meets WCAG AA against its background. Accents are used for emphasis, never for body copy.
- **Intentional motion.** Animation only when it clarifies (state change, spatial continuity). No motion for motion's sake. Respect `prefers-reduced-motion`.
- **Real copy, no slop.** Headlines and body come from each repo's actual purpose. No lorem ipsum, no fabricated stats or benchmark numbers. Any illustrative UI data is labeled *illustrative*.
- **Absolutely no generic AI-gradient slop.** No purple-to-blue hero gradients, no glassmorphism-by-default, no meaningless 3D blobs.

## 2. Palette

The montage banner and repo chrome use a restrained, near-black system with a single teal accent.

| Token | Hex | Use |
|-------|-----|-----|
| `bg` | `#0b0e14` | Near-black background |
| `panel` | `#11161f` | Cards / contact-sheet cells |
| `border` | `#1f2733` | Hairlines, dividers |
| `text` | `#e6edf3` | Primary text |
| `muted` | `#8b98a9` | Secondary text, labels |
| `accent` | `#5eead4` | The one teal accent (used sparingly) |

Individual mockups carry **their own** accent appropriate to the repo and the day's style — the palette above is the repo's own brand chrome, not a constraint on the mocks.

## 3. Type

- **Display / headline:** a strong sans (system UI stack) at large sizes for hero statements; serif is used in the *editorial* family for contrast.
- **Body:** clean sans, 16–18px equivalent, comfortable measure (~60–75 characters).
- **Mono:** used for labels, repo slugs, and the *terminal-dark* family.

## 4. The four style families

A rotation keeps the practice broad. Each day maps to a family; each mock varies accent and layout so a week shows range.

| Family | When | Feel |
|--------|------|------|
| **terminal-dark** | Mon / Thu | Near-black dev-tool surface; mono accents; one electric accent per mock (Linear / Vercel / Raycast energy) |
| **editorial** | Tue / Fri | Light, calm; strong serif headline + clean sans; generous whitespace (Stripe-essay calm) |
| **hud** | Wed / Sat | Top Gun aviation-instrument; amber/green readouts, subtle grid, restrained — never cheesy game UI |
| **blueprint** | Sun (designer's choice) | Architectural schematic; drafting grid, technical annotations |

See [`styles/`](styles/) to browse every mock by family.

---

## 5. Discoverability (aligned with Google Search guidance)

This repo is built to be found. The strategy follows Google's [SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide) and [Creating helpful, reliable, people-first content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content):

1. **Crawlable & public.** The single biggest reach lever is being a *public* repository with a *live* site. GitHub Pages serves the gallery at the homepage URL so search engines and people can reach the work without a login.
2. **Descriptive, unique titles.** The repo title and each page's H1 say plainly what the page is ("Daily UI Design Inspiration from Trending GitHub Repos"), not a clever-but-opaque name alone.
3. **Helpful, people-first content.** Every mock has real context: the source repo, the style family, the *one idea tested*, and an honest self-verdict. The catalog answers "show me a good landing-page design for an AI dev tool" with real examples.
4. **Anticipate how people search.** Copy naturally includes the terms a designer or engineer would type — *UI inspiration, web-design examples, landing-page design, hero section, front-end reference, design showcase, dev-tool UI, agent UI* — without keyword stuffing.
5. **Descriptive link text.** Links say where they go ("full design catalog", "browse by style"), not "click here".
6. **Logical directory structure.** Content is grouped in meaningful directories — [`days/`](days/) (by date), [`styles/`](styles/) (by visual family) — which both humans and crawlers can navigate.
7. **Topics & description.** The GitHub repo description and topics carry the primary keywords/synonyms so the repo surfaces in GitHub and web search.
8. **Promote the work.** A montage banner (`assets/banner.png`) gives the README and any shared link a strong visual; the same image can be set as the repo's social-preview (Settings → Social preview) so links unfurl well on the web and social platforms.

> [!note]
> Honesty stays first. No fabricated benchmarks, no fake stars, no cloaking. Discoverability here means *clear, accurate, well-structured* content — the kind both Google's guidance and good design ask for.

---

<sub>Maintained by the GooseDesigns generator (`tools/Build-GooseDesigns.ps1`). Banner by `tools/make_banner.py`.</sub>
