---
name: update-banner
description: Regenerates Documentation/Assets/banner.svg following the project's canonical 6-color palette and layout rules. Use when asked to 'update the banner', 'add a provider to the banner', 'refresh the banner', or 'change the banner'.
allowed-tools: Read, Write, Glob
argument-hint: "[description of what to change — e.g. 'add GeminiProvider box', 'mark OpenAI as coming soon']"
---

You are the banner author for AIProviderKit. Your job is to update `Documentation/Assets/banner.svg` following the canonical design rules below.

## Canonical 6-color palette

| Token       | Hex       | Usage                                                              |
|-------------|-----------|--------------------------------------------------------------------|
| `$BG`       | `#0F0F13` | SVG background fill (gradient end: `#18181F`)                     |
| `$ORANGE`   | `#F05138` | Swift accent bar, AIClient border/glow, orange rule, Skills badge |
| `$WHITE`    | `#E8E8F0` | Primary text (package name, box labels)                           |
| `$GRAY`     | `#6B6B75` | Muted text, dividers, arrows, upcoming / disabled providers       |
| `$BLUE`     | `#3B82F6` | Apple Intelligence provider, Streaming badge                      |
| `$GREEN`    | `#22C55E` | OpenAI provider, Tools badge                                      |

**Derived tints (do NOT introduce additional hues):**
- Slightly lighter `$ORANGE` tint for Claude box label: `#F0D090` (warm yellow — still orange family)
- `$BLUE` at 15% opacity for Apple Intelligence box fill
- `$GREEN` at 15% opacity for OpenAI box fill
- `$ORANGE` at 15% opacity for Claude box fill and AIClient fill
- `$GRAY` at 20% opacity for upcoming provider box fills

**Rule: never add a 7th hue. If you need a new provider accent, derive it from `$ORANGE`, `$BLUE`, or `$GREEN`.**

## Upcoming / disabled providers

Upcoming providers use the muted gray treatment:
- Box stroke: `$GRAY` (`#6B6B75`) at 60% opacity
- Box fill: `#1A1A20` (flat, no gradient)
- Indicator dot: `$GRAY`
- Label text: `$GRAY`
- Optional "coming soon" label in `$GRAY`

Active providers use their accent color at full opacity for stroke, dot, and label.

## Fixed layout (900 × 240 px)

```
[4px orange bar] [LEFT SECTION — x:16–330] [1px gray divider x:345] [RIGHT SECTION — x:360–884]
```

**Left section:**
- Package name: `font-size="36"` `font-weight="700"` `fill="$WHITE"` at y≈75
- Orange rule: 2.5px tall rect below name
- Tagline: `font-size="13"` `fill` slightly lighter than `$GRAY`
- Feature badges: pill shape `rx="12"`, `fill="#18181F"`, `stroke="$GRAY"` at 40% opacity
  - Streaming → `$BLUE` label
  - Tools → `$GREEN` label
  - Skills → `$ORANGE` label
- Platform line: `font-size="11"` `fill="$GRAY"`

**Right section — architecture diagram:**
- "Your App" box: neutral dark fill `#1C1C24`, stroke `$GRAY`
- AIClient box: `$ORANGE` border + soft glow filter, gradient fill from `$ORANGE` at ~15% opacity
- Provider boxes: 140×32 px, `rx="6"`, stacked vertically with 42px pitch
  - Active: colored stroke + fill tint + colored dot + colored label
  - Upcoming: gray stroke + flat fill + gray dot + gray label
- Arrows between boxes: dashed `stroke-dasharray="4 3"` in `$GRAY`
- All arrow markers: `fill="$GRAY"`

## Steps

### 1 — Read the current banner

```
Read: Documentation/Assets/banner.svg
```

Note the current providers, their state (active/upcoming), and the exact coordinates of every provider box so you can add, remove, or reposition consistently.

### 2 — Plan the change

Apply `$ARGUMENTS` to decide what changes are needed:
- Adding a provider → compute new y positions (42px pitch), shift others if needed
- Removing a provider → close the gap
- Marking active/upcoming → swap color treatment only, keep coordinates

### 3 — Apply palette rules

For every color value in the SVG, map it to the canonical palette. Do not introduce any new hues. Use opacity variants of the 6 base colors for fills, borders, and glow effects.

### 4 — Write the updated SVG

```
Write: Documentation/Assets/banner.svg
```

Keep the SVG clean: use `<defs>` for gradients and filters, group related elements with comments, and maintain the existing viewBox and font stack.

### 5 — Report

Tell the user:
- What changed (which providers, states, text)
- The exact palette tokens used for each new element
- Any layout shifts (y-coordinate changes for provider rows)

## Palette quick-reference card

```
Background:  #0F0F13 → #18181F  (gradient)
Accent bar:  #F05138 → #D94C2A  (gradient, 4px left edge)
Orange:      #F05138   Claude stroke / AIClient border / Skills
Blue:        #3B82F6   Apple Intelligence stroke / Streaming badge
Green:       #22C55E   OpenAI stroke / Tools badge
White:       #E8E8F0   Primary labels
Gray:        #6B6B75   Muted text / dividers / upcoming providers
```
