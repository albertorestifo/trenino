---
name: Trenino
description: Bridge your custom hardware to Train Sim World
colors:
  # Brand colors. Rail red is brand-only: logo, installer icon and editorial
  # material. It is never a UI role and never appears in app code.
  brand-rail-red: "#D93920"
  brand-ink: "#20262C"
  brand-paper: "#F7F6F2"
  # Light theme interface tokens
  light-background: "#F7F6F2"
  light-surface: "#FFFFFF"
  light-text: "#20262C"
  light-muted: "#58616B"
  light-border: "#C4C9CE"
  light-action: "#4056B4"
  light-on-action: "#FFFFFF"
  light-success: "#146C53"
  light-warning: "#8A4B08"
  light-error: "#B42332"
  light-info: "#245A8D"
  # Dark theme interface tokens
  dark-background: "#20262C"
  dark-surface: "#2A323A"
  dark-text: "#F5F7FA"
  dark-muted: "#B7C0C9"
  dark-border: "#65717D"
  dark-action: "#AFBCFF"
  dark-on-action: "#20262C"
  dark-success: "#68D6AC"
  dark-warning: "#F3C36B"
  dark-error: "#FF9AA4"
  dark-info: "#91C8F6"
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
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontWeight: 400
    fontVariantNumeric: "tabular-nums"
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
    backgroundColor: "{colors.light-action} / {colors.dark-action}"
    textColor: "{colors.light-on-action} / {colors.dark-on-action}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.light-text} / {colors.dark-text}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.light-action} / {colors.dark-action}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  button-error:
    backgroundColor: "{colors.light-error} / {colors.dark-error}"
    textColor: "#FFFFFF / {colors.brand-ink}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  input:
    backgroundColor: "{colors.light-surface} / {colors.dark-surface}"
    textColor: "{colors.light-text} / {colors.dark-text}"
    borderColor: "{colors.light-border} / {colors.dark-border}"
    rounded: "{rounded.sm}"
    padding: "8px 12px"
  list-card:
    backgroundColor: "{colors.light-surface} / {colors.dark-surface}"
    textColor: "{colors.light-text} / {colors.dark-text}"
    borderColor: "{colors.light-border} / {colors.dark-border}"
    rounded: "{rounded.lg}"
    padding: "20px"
---

# Design System: Trenino

Token values in the front matter come from the Trenino Brand Guide v1.1 (`tokens/trenino-colors.json`). Component values are written as `light / dark`. The daisyUI theme blocks in `assets/css/app.css` are the implementation; templates use role classes, never hex values.

## 1. Overview

**Creative North Star: "The Maker's Workshop"**

Trenino is a tool for people who build things with their hands. The design system reflects that: organized, purposeful, with a place for everything. Every surface is calm and legible. There are no decorative distractions, no color for atmosphere, no motion to impress. Complexity is earned gradually, surfaced only when the user is ready for it.

The brand personality is **precise, tactile, calm**:

- **Precise:** aligned geometry and honest labels. Show what is connected and what is next.
- **Tactile:** the mark references the lever. Generous controls and clear borders.
- **Calm:** color is scarce and functional. No glow, gradients or decoration.

A maker sits at a desk with a half-assembled rig, an Arduino plugged in, a wiring diagram open in another tab. The interface needs to be readable at a glance, unambiguous in state, and forgiving in interaction. When something is connected, you know. When something fails, you know immediately and without ambiguity.

Light and dark themes share one design: the same roles, the same single indigo action family, the same rules. Only the token values change so each pair stays readable on its own background. Neither theme uses gradients or tonal drama. Both rely on clear structure: strong surface hierarchy, semantic color for state only, and type that leads the eye without effort.

This system explicitly rejects the aesthetics of cluttered dev tools (the Arduino IDE), industrial data panels (SCADA-style dashboards), and gaming-aesthetic dark modes with neon accents or glass effects. The goal is a tool that feels like a trusted instrument, not a product.

**Key Characteristics:**
- One indigo action family in both themes, used for actions and current/selected state
- Tactile and direct: substantial padding, clear borders, confident type weights
- Semantic color is functional, not decorative (success, warning, error, info only for real state, always with a label)
- Flat surfaces at rest; depth only for floating elements (modals, dropdowns)
- Monospace with tabular numbers for all technical values (port names, firmware versions, pins, raw and calibration numbers)

## 2. Colors

### Brand colors

- **Rail red** (`#D93920`): identifies the product in the logo, the installer/app icon and editorial material. It is **not** a UI color: never a button, never a status, never wired to a daisyUI role, never written in app code.
- **Cab graphite / ink** (`#20262C`) and **Workshop paper** (`#F7F6F2`): the brand neutrals. They double as dark background and light background.

### Interface roles

| Role | Light | Dark | daisyUI | Use |
|---|---|---|---|---|
| background | `#F7F6F2` | `#20262C` | `base-100` | Page background |
| surface | `#FFFFFF` | `#2A323A` | `base-200` | Cards, panels, inputs, modals, dropdowns, header |
| border | `#C4C9CE` | `#65717D` | `base-300` | Borders, dividers, hover fills |
| text | `#20262C` | `#F5F7FA` | `base-content` | All primary text |
| muted | `#58616B` | `#B7C0C9` | `text-muted` / `border-muted` | Secondary text, helper text, metadata, placeholders |
| action | `#4056B4` | `#AFBCFF` | `primary` (also `accent`) | Primary actions, links, current/selected state |
| on-action | `#FFFFFF` | `#20262C` | `primary-content` | Text on action fills |
| success | `#146C53` | `#68D6AC` | `success` | Connected, completed |
| warning | `#8A4B08` | `#F3C36B` | `warning` | Needs attention |
| error | `#B42332` | `#FF9AA4` | `error` | Failed, destructive |
| info | `#245A8D` | `#91C8F6` | `info` | Informational notices, update banners |

Derived roles the brand does not define: `secondary` = muted, `accent` = action, `neutral` = ink (`#20262C` light, `#3A444D` dark). Do not reach for `secondary` or `accent` to add color; they exist so daisyUI components render in brand.

All text and semantic foregrounds exceed 4.5:1 on their theme's background and surface (`tokens/contrast-checks.csv`).

### Named Rules

**The One Action Family Rule.** Indigo carries primary actions in both themes. It is also allowed for current or selected state: the active nav tab, the current wizard step, a selected card border. It is not used on decorative icons, stats, spinners or headings; those use `text-base-content` or `text-muted`.

**The Semantic Firewall Rule.** Green, amber, red and blue are reserved for real state (hardware, connection, operation results). They are forbidden as decorative accents, category colors, background washes or typography highlights. A category such as "analog" or "linear" is a `badge-ghost`, not a colored badge. Red always means failure or a destructive action, nothing else.

**The Muted Token Rule.** Secondary text uses `text-muted`, never `text-base-content/40`, `/50` or `/60` (those fail 4.5:1 in the light theme). Never use faint opacity for essential instructions. Opacity remains acceptable on purely decorative icons and dividers. Muted text sits on `base-100` or `base-200`, never on `base-300` (3.77:1 in light).

**The Foreground Pair Rule.** Status colors are foregrounds on neutral surfaces. In dark mode every `-content` color on an action or status fill is ink `#20262C`, not white. Do not assume white text works on a colored fill.

## 3. Typography

**Body/UI Font:** System UI stack (system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif)
**Technical Value Font:** System monospace (ui-monospace, SFMono-Regular, Menlo, Consolas, monospace) with tabular numbers

**Character:** The system does not use a custom typeface. The system UI stack is deliberate: it matches what the user's OS renders everywhere else, reducing cognitive friction. The monospace stack is the second personality, used for technical values, making them instantly scannable as "this is a machine thing, not a label." The wordmark is fixed outlined artwork; never retype or substitute it in a font.

### Scale

| Level | Size | Weight | Tailwind | Use |
|---|---|---|---|---|
| Page title | 24px | semibold | `text-2xl font-semibold` | One per screen; page and wizard headings |
| Section title | 20px | semibold | `text-xl font-semibold` | Section headings, modal titles, card headings |
| Body | 14px / 1.6 | regular | `text-sm` (base) | Descriptive text, form labels, table content, alerts, banners |
| Metadata | 12px minimum | regular | `text-xs` | Helper text, timestamps, empty-state sublines, in `text-muted` |
| Mono | inherits size | regular | `font-mono` | Technical values; tabular numbers are applied globally |

Nothing renders below 12px. No `text-[10px]`, `text-[9px]` or smaller. Non-mono numeric readouts get `tabular-nums` so digits do not jitter as values change.

### Named Rules

**The Mono Signal Rule.** If a value was generated by hardware or software (a port name, a version string, a pin number, a raw or calibration value, an internal ID), render it in `font-mono`. If a human typed it (a train name, a description), render it in the body font. This is the boundary. Do not cross it.

## 4. Elevation

The system is flat by default. daisyUI runs with `--depth: 0`, so buttons, alerts, badges and cards have no bevel or drop shadow. Cards, list rows and panels separate from the page through surface layering: `base-200` surface on `base-100` background, outlined with `base-300`. Depth is created by color and border, not by blur.

Shadows are reserved for floating surfaces that visually detach from the page: modals, dropdown menus and device panels. These sit on `bg-base-200` and use a single shadow level (`shadow-xl`).

### Named Rules

**The Flat-By-Default Rule.** Surfaces are flat at rest. A card does not have a shadow. A list item does not have a shadow. No glows, tinted shadows, halo rings (`ring-4 ring-*/30`) or scale-on-active. If you are reaching for `box-shadow` on a non-floating element, stop and use a background tint or border instead. Focus and current-state emphasis use a solid 2px outline or border.

## 5. Identity

Logo files live in `priv/static/images/`:

- `trenino-lockup-primary.svg`: red symbol and ink wordmark, for light backgrounds.
- `trenino-lockup-dark.svg`: red symbol and white wordmark, for dark neutral backgrounds.
- `trenino-symbol-red.svg`: the standalone symbol.
- `trenino-app-icon.svg`: white symbol on the rail-red tile (app icon, favicon).

Rules:

- **Theme pairing:** primary lockup on light, dark lockup on dark. Swap with `block dark:hidden` / `hidden dark:block`.
- **Minimum size:** lockup at least 140px wide (at 40px tall, `h-10 w-auto`, it is about 145px). Below that, use the standalone symbol, at least 24px wide. At 16px use only the app tile / favicon; no wordmark at that size.
- **Clear space:** at least 1/4 of the visible symbol height around the whole logo. The SVG canvas padding does not count toward it.
- **Integrity:** do not flip or mirror, stretch, rotate, shade, outline, add shadows to, recolor or resize individual parts. Keep the right-leaning orientation. Place it on a solid neutral surface, never on busy imagery.
- **Accessibility:** the nav logo link keeps a text label (`aria-label="Trenino, home"`).
- **Red is brand-only:** rail red appears in the logo and app tile, never elsewhere in the UI.

## 6. Voice and copy

Write as a calm, precise guide standing next to the rig.

- Plain, direct instructions: "Connect your controller", "Move the lever through its full range".
- Confirmations are short and do not say "successfully": "Calibration saved", "Configuration applied".
- **Errors explain the next step:** "Controller disconnected. Check the USB cable and reconnect." Never show raw terms such as `inspect(reason)` or atoms to users; log them with `Logger` and show a plain sentence. When the cause is unknown, still give a next step: "Something unexpected happened. Try again, and if it continues, check the log and report it."
- Write "Trenino" in prose. Lowercase "trenino" exists only in the wordmark artwork and in machine identifiers.
- No exclamation marks. New and rewritten copy uses sentence case.
- Status labels use the shared vocabulary: **Connected**, **Connecting**, **Needs attention**, **Failed**.
- Browser titles read "Page · Trenino" (for example "Trains · Trenino").

## 7. Components

### Buttons

Tactile and direct. Substantial padding, squared corners (4px radius), confident weight. The primary button is the loudest element on any surface and should be the only one.

- **Shape:** Gently squared corners (4px radius / `rounded-sm`). Not pill, not sharp.
- **Primary:** action background, on-action text, both themes. Padding 8px 16px. Also the button for every non-destructive confirm ("Confirm", "Use this endpoint").
- **Primary Soft:** Tinted version of the primary color at low opacity, primary-colored text. Used when a primary-level action needs to feel less dominant.
- **Ghost:** Transparent background, body text color. For secondary actions and cancels. Hover reveals a subtle base-200 tint.
- **Outline:** Transparent background, primary-colored border and text. Used for "Install firmware" and similar secondary-but-notable actions in context.
- **Error:** error background, error-content text. Only for destructive confirms (delete, erase) in confirmation modals and danger zones. Never for cancels or ordinary confirms.
- **Never** use `btn-success` for a confirm. Green is a state, not an action.
- Stop buttons on motor and gauge hardware use `btn btn-neutral` with a `hero-stop-solid` icon: prominent ink, never red (red is reserved for failure and destructive actions) and never competing with the indigo primary next to it.
- Toggle-style buttons show their "on" state with `btn-primary` (selected), not `btn-success`.
- **States:** Hover is daisyUI's default. Focus visible shows a 2px outline in the primary color offset by 2px. Disabled buttons use daisyUI's disabled style; any text that must still be read uses `text-muted`, not extra opacity.
- **Size variants:** `btn-sm` (compact, inside cards/dropdowns), default (main flow actions).

### Toggles

Toggles are controls, not state indicators: use `toggle-primary` everywhere.

### Inputs / Fields

Structured inside a `fieldset` wrapper with a `label` above. The label is a small span in `text-muted`. Error messages appear below with a red exclamation icon inline.

- **Style:** surface background (`base-200`), 4px radius, 1.5px border in `base-300`. Full-width by default.
- **Placeholders:** `placeholder:text-muted`, not italic. Placeholders never carry the only instruction.
- **Focus:** Border shifts to primary color. No glow, no shadow. The border change alone is the signal.
- **Error state:** Border and icon shift to error. Error text appears below in `text-xs text-error` with heroicon exclamation-circle inline.
- **Disabled:** daisyUI's disabled style, no cursor.
- **Monospace hint:** If a field accepts a hardware identifier or port name, apply `font-mono` to the input itself so the value renders in mono as the user types.

### Cards / Containers

- **List Card** (signature component): Used in train and device list views. 12px radius (`rounded-xl`), 1px base-300 border, base-200 surface. Hover deepens the fill. The active state uses a 2px success border, a faint success/5 tint and an "Active" status chip. The card title shifts to primary on hover (`group-hover:text-primary`) as an action affordance. Chevron right icon in the trailing position.
- **Modal:** Fixed overlay with a 50% black scrim (`bg-black/50`). Content panel is `bg-base-200`, 12px radius, `shadow-xl`. Max width 28rem (max-w-md). Internal padding 24px.
- **Danger Zone:** Not a card. A section within an edit page, separated by a top border in base-300. The action area inside has a 30% opacity error-colored border and 5% error tint background: enough to register "destructive territory" without alarming.
- **Empty State Panel:** base-100 background, 8px radius, 32px internal padding, centered. Icon in `text-muted`. Message in body, sub-message in metadata (`text-xs text-muted`). Empty states say what to do next ("Click scan to discover devices"). No border.

### Navigation

Sticky top bar on `bg-base-200` with a 1px base-300 bottom border. Trenino lockup at the leading edge (see Identity). Content constrained to max-w-2xl. Navigation tabs (text links with active state) and icon-labeled control buttons for Settings and Devices.

- **Tab style:** Inactive: base-content text, transparent background, hover reveals base-300 tint. Active: primary background, primary-content text (current state). 8px radius. No underlines, no side borders.
- **Control buttons** (Settings, Devices): base-200 background, hover reveals base-300. Icon + label (hidden on mobile, with `sr-only` text). 8px radius.
- **Device status:** A dot is never the only signal. Each state shows an icon and a text label from the shared vocabulary: Connected (`hero-check-circle-mini`, success), Connecting (`hero-arrow-path-mini motion-safe:animate-spin`, info), Needs attention (`hero-exclamation-triangle-mini`, warning), Failed (`hero-x-circle-mini`, error). The idle state also has text ("No controllers"). At summary level a failed device reads "Needs attention"; the device row reads "Failed" with the next step. No pulsing dots.
- **Device Dropdown:** Absolute panel below the Devices button. `bg-base-200`, 12px radius, `shadow-xl`, 1px base-300 border. Scrollable device list with a hover tint on each row. Ports and versions in `font-mono`.

### Breadcrumbs

Slim secondary bar directly beneath the nav header. base-200 background, 1px base-300 bottom border. Body text, chevron-right mini separators. Current page item is full-weight base-content; ancestor items are `text-muted` with hover transition to base-content.

### Alerts / Flash / Banners

DaisyUI `alert` in the soft variant: `alert alert-soft alert-info|success|warning|error`. Flash messages sit inside a `toast toast-top toast-end` container. Each includes a leading heroicon (information-circle or exclamation-circle), optional title in semibold, body text, and a dismiss button. Info alerts auto-dismiss after 5 seconds. Max width 24rem (max-w-96).

Header banners (app update, firmware update) are notices, not actions: they use the info role in the soft treatment, with a status-colored icon and base-content text at `text-sm`. The simulator error banner may keep a solid error fill so it stands out; it is the only solid status fill.

### Status Badges

Status badges use the soft variant (`badge badge-soft badge-*`), preferably through `<.status_chip>`, which pairs an icon with the label. The label is always present. No pulse dot: the word carries the state. `badge-success` / "Active" for the active train or configuration.

Category badges (input type, lever type, analog/button, gate/linear) are `badge-ghost`. Status colors on a badge always mean real state.

## 8. Motion

- No decorative animation. No `animate-pulse` on dots, badges or icons.
- In-progress states (connecting, uploading, waiting) use a spinner icon (`hero-arrow-path-mini motion-safe:animate-spin`) next to a text label.
- Every kept animation is guarded with `motion-safe:`. Reduced-motion users see a static icon and the same text.
- State transitions use opacity and transform only, ease-out, 150–300ms. Never animate layout properties.

## 9. Do's and Don'ts

### Do:

- **Do** use status colors only for real state, and always with a text label. Green means connected or completed; amber means needs attention; red means failed or destructive.
- **Do** render technical values (port names, firmware versions, pins, raw and calibration numbers) in `font-mono` with tabular numbers.
- **Do** use `text-muted` for secondary text and keep every text size at 12px or above.
- **Do** use surface tints (base-100, base-200, base-300) and borders for depth within a page. Reserve `shadow-xl` for modals and dropdowns only.
- **Do** surface complex actions progressively: wizards for first-time setup, compact controls for experienced users once configuration is complete.
- **Do** use large, clearly bordered interactive targets. Users may be cross-referencing wiring diagrams or have tools in hand. Precise taps should not be required.
- **Do** use daisyUI role classes for color. Brand hex values live only in the theme blocks in `assets/css/app.css`; never hardcode a color in a template.
- **Do** make every error explain the next step.
- **Do** constrain all content to max-w-2xl centered layout. The narrower column improves readability and makes the interface feel organized rather than sprawling.

### Don't:

- **Don't** use status colors (green, amber, red, blue) for decoration, emphasis, categories or branding. A green heading is forbidden. An amber badge on a new feature is forbidden.
- **Don't** use rail red anywhere in the UI. It belongs to the logo and app icon.
- **Don't** use the primary color on decorative icons, stats, spinners or section headings. It belongs on actions and current/selected state.
- **Don't** use `btn-success` or `btn-error` for non-destructive confirms or cancels.
- **Don't** use opacity (`text-base-content/40`, `/50`, `/60`) for text. Use `text-muted`.
- **Don't** show `inspect(reason)`, atoms or stack traces to users.
- **Don't** add shadows to cards, list rows, or inline panels. The flat surface hierarchy is deliberate. If it needs more distinction, use a background tint or border.
- **Don't** expose all configuration options at once. The anti-reference here is the Arduino IDE: walls of dropdowns, no hierarchy, no guided path. Use progressive disclosure.
- **Don't** reproduce SCADA-dashboard aesthetics: dense data tables as the primary layout, no breathing room, numerical readouts as the dominant visual element.
- **Don't** use neon accents, gradients, gradient overlays, glows, glassmorphism, or any visual treatment associated with gaming-peripheral software. The dark theme is calm and instrumental, not a gaming rig screensaver.
- **Don't** use side-stripe borders (border-left or border-right wider than 1px) as colored accents on cards or list items. Use full borders, background tints, or nothing.
- **Don't** use gradient text (background-clip: text). Emphasis through weight or size only.
- **Don't** add decorative or persistent motion. See Motion.
- **Don't** rely on color alone to convey state. Status dots and semantic colors are always paired with an icon or label. Users may be colorblind.
