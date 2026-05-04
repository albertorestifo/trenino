---
name: Trenino
description: Bridge your custom hardware to Train Sim World
colors:
  electric-indigo: "oklch(58% 0.233 277.117)"
  electric-indigo-content: "oklch(96% 0.018 272.314)"
  copper-signal: "oklch(70% 0.213 47.604)"
  copper-signal-content: "oklch(98% 0.016 73.684)"
  surface-dark: "oklch(30.33% 0.016 252.42)"
  surface-dark-sunken: "oklch(25.26% 0.014 253.1)"
  surface-dark-deep: "oklch(20.15% 0.012 254.09)"
  text-on-dark: "oklch(97.807% 0.029 256.847)"
  surface-light: "oklch(98% 0 0)"
  surface-light-raised: "oklch(96% 0.001 286.375)"
  surface-light-border: "oklch(92% 0.004 286.32)"
  text-on-light: "oklch(21% 0.006 285.885)"
  muted-slate: "oklch(37% 0.044 257.287)"
  signal-green: "oklch(60% 0.118 184.704)"
  signal-amber: "oklch(66% 0.179 58.318)"
  signal-red: "oklch(58% 0.253 17.585)"
  signal-blue: "oklch(58% 0.158 241.966)"
typography:
  display:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "1.5rem"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "normal"
  headline:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: 1.4
  title:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.5
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "0.75rem"
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, 'Cascadia Code', monospace"
    fontSize: "0.75rem"
    fontWeight: 400
    lineHeight: 1.5
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
  full: "9999px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.electric-indigo}"
    textColor: "{colors.electric-indigo-content}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-primary-hover:
    backgroundColor: "oklch(62% 0.233 277.117)"
  button-primary-light:
    backgroundColor: "{colors.copper-signal}"
    textColor: "{colors.copper-signal-content}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.text-on-dark}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.electric-indigo}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-error:
    backgroundColor: "{colors.signal-red}"
    textColor: "oklch(96% 0.015 12.422)"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  input:
    backgroundColor: "{colors.surface-dark-sunken}"
    textColor: "{colors.text-on-dark}"
    rounded: "{rounded.sm}"
    padding: "8px 12px"
  list-card:
    backgroundColor: "{colors.surface-dark-sunken}"
    textColor: "{colors.text-on-dark}"
    rounded: "{rounded.lg}"
    padding: "20px"
---

# Design System: Trenino

## 1. Overview

**Creative North Star: "The Maker's Workshop"**

Trenino is a tool for people who build things with their hands. The design system reflects that: organized, purposeful, with a place for everything. Every surface is calm and legible. There are no decorative distractions, no color for atmosphere, no motion to impress. Complexity is earned gradually, surfaced only when the user is ready for it.

The dark theme is the primary context. A maker at a desk with a half-assembled rig, an Arduino plugged in, a wiring diagram open in another tab. The interface needs to be readable at a glance, unambiguous in state, and forgiving in interaction. When something is connected, you know. When something fails, you know immediately and without ambiguity.

The light theme serves users in bright environments or those who prefer it. Its warm-orange primary keeps the energy direct and confident rather than corporate. Neither theme uses gradients or tonal drama. Both rely on clear structure: strong surface hierarchy, semantic color for state only, and type that leads the eye without effort.

This system explicitly rejects the aesthetics of cluttered dev tools (the Arduino IDE), industrial data panels (SCADA-style dashboards), and gaming-aesthetic dark modes with neon accents or glass effects. The goal is a tool that feels like a trusted instrument, not a product.

**Key Characteristics:**
- Restrained color strategy: primary accent used only on actionable, foregrounded elements
- Dual theme with distinct personalities: Electric Indigo (dark), Copper Signal (light)
- Tactile and direct: substantial padding, clear borders, confident type weights
- Semantic color is functional, not decorative (success, warning, error, info only for state)
- Flat surfaces at rest; depth only for floating elements (modals, dropdowns)
- Monospace type for all technical identifiers (port names, firmware versions, hardware IDs)

## 2. Colors: The Workshop Palette

A dual-theme system with distinct primaries. Semantic colors (signal-green, signal-amber, signal-red, signal-blue) are shared across both themes and used exclusively for hardware and connection state.

### Primary

- **Electric Indigo** (oklch(58% 0.233 277.117)): The dark theme's action color. Used on primary buttons, active navigation tabs, and focused interactive elements. Vibrant enough to read against dark surfaces without glowing. Never used decoratively.
- **Copper Signal** (oklch(70% 0.213 47.604)): The light theme's action color. A warm, direct orange that reads as energetic but not aggressive. Same semantic role as Electric Indigo; same usage rules.

### Secondary

- **Muted Slate** (oklch(37% 0.044 257.287)): Used for neutral UI elements in the dark theme — separators, inactive chip backgrounds, and secondary surface layering where base-200 isn't distinct enough.

### Tertiary

None. The system avoids a third accent to maintain restraint. Semantic signals handle every other color role.

### Neutral

- **Workshop Slate** (oklch(30.33% 0.016 252.42)): Dark theme primary surface (base-100). The main background.
- **Workshop Slate Sunken** (oklch(25.26% 0.014 253.1)): Inputs, inner panels, and surfaces that sit below the primary layer.
- **Workshop Slate Deep** (oklch(20.15% 0.012 254.09)): The deepest surface — borders, dividers, structural edges.
- **Near-white on Dark** (oklch(97.807% 0.029 256.847)): Primary text on dark. Slightly blue-tinted to harmonize with the surface hue.
- **Workshop White** (oklch(98% 0 0)): Light theme primary surface. Neutral, very slightly warm.
- **Cool Raised** (oklch(96% 0.001 286.375)): Light theme raised surface (inputs, inner panels).
- **Cool Border** (oklch(92% 0.004 286.32)): Light theme borders and structural edges.
- **Near-black on Light** (oklch(21% 0.006 285.885)): Primary text on light.

### Semantic (Shared Across Themes)

- **Signal Green** (oklch(60% 0.118 184.704)): Connected, active, successful. Used on status dots, active badges, success alerts.
- **Signal Amber** (oklch(66% 0.179 58.318)): Warning, degraded, or transitional state. Used on status dots, warning alerts, disabled-reason text.
- **Signal Red** (oklch(58% 0.253 17.585)): Error, failed, destructive. Used on status dots, error alerts, danger zone actions.
- **Signal Blue** (oklch(58% 0.158 241.966)): Informational, discovering, in-progress. Used on connecting status dots, info alerts, update banners.

### Named Rules

**The Semantic Firewall Rule.** Signal colors (green, amber, red, blue) are reserved for hardware and connection state. They are forbidden as decorative accents, background washes, or typography highlights. A green on screen means something is connected. Full stop.

**The One Voice Rule.** The primary accent (Electric Indigo or Copper Signal) appears only on foregrounded, actionable surfaces: buttons, active nav tabs, active card borders. Its rarity is what makes it readable. Do not use it on text, icons, or section headings.

## 3. Typography

**Body/UI Font:** System UI stack (system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif)
**Technical Identifier Font:** System monospace (ui-monospace, SFMono-Regular, Menlo, Monaco, "Cascadia Code", monospace)

**Character:** The system does not use a custom typeface. The system UI stack is deliberate: it matches what the user's OS renders everywhere else, reducing cognitive friction. The monospace stack is the second personality — used exclusively for hardware port names, firmware version strings, and device identifiers, making technical values instantly scannable as "this is a machine thing, not a label."

### Hierarchy

- **Display** (600 weight, 1.5rem / 24px, lh 1.3): Page titles and wizard headings. Appears at most once per screen.
- **Headline** (600 weight, 1.25rem / 20px, lh 1.4): Section titles within complex edit pages. Used sparingly.
- **Title** (600 weight, 1.125rem / 18px, lh 1.5): Card headings, modal titles, and navigation-level labels.
- **Body** (400 weight, 0.875rem / 14px, lh 1.6): All descriptive text, form labels, table content, alert messages.
- **Label** (400 weight, 0.75rem / 12px, lh 1.5): Secondary metadata, helper text, timestamps, empty-state sublines. Always in a muted color (base-content at 50–70% opacity).
- **Mono** (400 weight, 0.75rem / 12px, lh 1.5): Port names, firmware versions, hardware identifiers, and any value that is machine-generated rather than human-authored.

### Named Rules

**The Mono Signal Rule.** If a value was generated by hardware or software (a port name, a version string, an internal ID), render it in monospace. If a human typed it (a train name, a description), render it in the body font. This is the boundary. Do not cross it.

## 4. Elevation

The system is flat by default. Cards, list rows, and panels use surface layering through background tints (base-100, base-200, base-300), not shadows. Depth is created by color, not by blur or drop shadows.

Shadows are reserved exclusively for floating surfaces that visually detach from the page: modals, dropdown menus, and device panels. These use a single shadow level (`shadow-xl`) that creates clear detachment without drama.

### Shadow Vocabulary

- **Floating** (`box-shadow: 0 20px 60px rgba(0,0,0,0.35), 0 4px 16px rgba(0,0,0,0.20)`): Modals and dropdown menus. Signals "I am above the page." Used nowhere else.

### Named Rules

**The Flat-By-Default Rule.** Surfaces are flat at rest. A card does not have a shadow. A list item does not have a shadow. If you are reaching for `box-shadow` on a non-floating element, stop and use a background tint or border instead.

## 5. Components

### Buttons

Tactile and direct. Substantial padding, squared corners (4px radius), confident weight. The primary button is the loudest element on any surface and should be the only one.

- **Shape:** Gently squared corners (4px radius / `rounded-sm`). Not pill, not sharp.
- **Primary:** Electric Indigo background (dark) or Copper Signal (light), near-white text. Padding 8px 16px. Bold enough to be the clear primary action.
- **Primary Soft:** Tinted version of the primary color at low opacity, primary-colored text. Used when a primary-level action needs to feel less dominant.
- **Ghost:** Transparent background, body text color. For secondary actions adjacent to a primary. Hover reveals a subtle base-200 tint.
- **Outline:** Transparent background, primary-colored border and text. Used for "Install Firmware" and similar secondary-but-notable actions in context. The border makes it visible without competing with the primary.
- **Error:** Signal Red background, error-content text. Appears only in confirmation modals and danger zones. Never in normal flows.
- **States:** Hover lightens background by ~1 lightness step. Focus visible shows a 2px ring in the primary color offset by 2px. Disabled at 40% opacity, no pointer.
- **Size variants:** `btn-sm` (compact, inside cards/dropdowns), default (main flow actions).

### Inputs / Fields

Structured inside a `fieldset` wrapper with a `label` above. The label is a small, muted span. Error messages appear below with a red exclamation icon inline.

- **Style:** `surface-dark-sunken` background (in dark), `surface-light-raised` (in light). 4px radius. 1.5px border in base-300 color. Full-width by default.
- **Focus:** Border shifts to primary color. No glow, no shadow. The border change alone is the signal.
- **Error state:** Border and icon shift to Signal Red. Error text appears below in `text-xs text-error` with heroicon exclamation-circle inline.
- **Disabled:** 40% opacity, no cursor. No special styling needed beyond that.
- **Monospace hint:** If a field accepts a hardware identifier or port name, apply `font-mono` to the input itself so the value renders in mono as the user types.

### Cards / Containers

- **List Card** (signature component): Used in train and device list views. Rectangular block with 12px radius (`rounded-xl`), 1px base-300 border, base-200/50 background. Hover reveals solid base-200 fill. The active state uses a 2px success-colored border and a faint success/5 background tint. The card title animates to primary on hover (`group-hover:text-primary`). Chevron right icon in the trailing position.
- **Modal:** Fixed overlay with 50% black scrim. Content panel is base-100, 12px radius, `shadow-xl`. Max width 28rem (max-w-md). Internal padding 24px.
- **Danger Zone:** Not a card. A section within an edit page, separated by a top border in base-300. The action area inside has a 30% opacity error-colored border and 5% error tint background — enough to register "destructive territory" without alarming.
- **Empty State Panel:** base-100 background, 8px radius, 32px internal padding, centered. Icon at 30% opacity. Message in body, sub-message in label. No border.

### Navigation

Sticky top bar on base-100 with a 1px base-300 bottom border. Content constrained to max-w-2xl. Two navigation tabs (text links with active state) and two icon-labeled control buttons for Settings and Devices.

- **Tab style:** Inactive: base-content/70 text, transparent background, hover reveals base-200 tint. Active: primary-color background, primary-content text. 8px radius. No underlines, no side borders.
- **Control buttons** (Settings, Devices): base-200 background, hover reveals base-300. Icon + label (hidden on mobile). A 2×2 status dot precedes the icon to show live state. 8px radius.
- **Status dots:** 8×8px circle (w-2 h-2). Signal Green for connected, Signal Blue with animate-pulse for connecting/discovering, Signal Amber for degraded, Signal Red for failed, base-content/20 for idle/unknown.
- **Device Dropdown:** Absolute panel below the Devices button. base-100 background, 12px radius, shadow-xl, 1px base-300 border. Scrollable device list with 4px hover tint on each row.

### Breadcrumbs

Slim secondary bar directly beneath the nav header. base-200/50 background, 1px base-300 bottom border. Small body text, chevron-right mini separators. Current page item is full-weight base-content; ancestor items are 70% opacity with hover transition to full.

### Alerts / Flash

DaisyUI `alert` component inside a `toast toast-top toast-end` container. Info alerts use Signal Blue; Error alerts use Signal Red. Both include a leading heroicon (information-circle or exclamation-circle), optional title in semibold, body text, and a dismiss button. Info alerts auto-dismiss after 5 seconds. Max width 24rem (max-w-96).

### Status Badges

Small badges (`badge badge-sm`) used inline in card titles to show active state. Always include an animated pulse dot alongside text. `badge-success` for active train. Never used decoratively.

## 6. Do's and Don'ts

### Do:

- **Do** use Signal colors exclusively for hardware and connection state. If it's green, something is connected. If it's red, something failed. This mapping must never be diluted.
- **Do** render machine-generated values (port names, firmware versions, device IDs) in monospace. The visual distinction tells users instantly whether a value is human or machine.
- **Do** use surface tints (base-200, base-300) for depth within a page. Reserve `shadow-xl` for modals and dropdowns only.
- **Do** surface complex actions progressively — wizards for first-time setup, compact controls for experienced users once configuration is complete.
- **Do** use large, clearly bordered interactive targets. Users may be cross-referencing wiring diagrams or have tools in hand. Precise taps should not be required.
- **Do** use OKLCH for all new color values. Reduce chroma as lightness approaches 0 or 100 to avoid garish extremes.
- **Do** constrain all content to max-w-2xl centered layout. The narrower column improves readability and makes the interface feel organized rather than sprawling.

### Don't:

- **Don't** use Signal colors (green, amber, red, blue) for decoration, emphasis, or branding. They are reserved for hardware state. A green heading is forbidden. An amber badge on a new feature is forbidden.
- **Don't** use the primary accent (Electric Indigo or Copper Signal) on text, icons, or section labels. It belongs only on actionable, foregrounded surfaces.
- **Don't** add shadows to cards, list rows, or inline panels. The flat surface hierarchy is deliberate. If it needs more distinction, use a background tint or border.
- **Don't** expose all configuration options at once. The anti-reference here is the Arduino IDE: walls of dropdowns, no hierarchy, no guided path. Use progressive disclosure.
- **Don't** reproduce SCADA-dashboard aesthetics: dense data tables as the primary layout, no breathing room, numerical readouts as the dominant visual element.
- **Don't** use neon accents, gradient overlays, glassmorphism, or any visual treatment associated with gaming-peripheral software. The dark theme is calm and instrumental, not a gaming rig screensaver.
- **Don't** use side-stripe borders (border-left or border-right wider than 1px) as colored accents on cards or list items. Use full borders, background tints, or nothing.
- **Don't** use gradient text (background-clip: text). Emphasis through weight or size only.
- **Don't** add motion to layout properties. Status dot pulse (animate-pulse) is the only persistent animation. State transitions use opacity and transform only, ease-out, 150–300ms.
- **Don't** rely on color alone to convey state. Status dots and semantic colors are always paired with an icon or label. Users may be colorblind.
