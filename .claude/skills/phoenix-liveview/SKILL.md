---
name: phoenix-liveview
description: Use when writing or changing LiveViews, components, HEEx templates, routes, or frontend styles in this project.
---

# Phoenix and LiveView in Trenino

DESIGN.md and PRODUCT.md govern visual and UX decisions.

## HEEx

- Interpolate with `{...}` in attributes and in body values. Use `<%= ... %>` only for block constructs such as `if`, `for` and `case`.
- Write comments as `<%!-- comment --%>`.
- Add `phx-no-curly-interpolation` to a tag that shows literal `{` or `}`.
- A `phx-hook` element that manages its own DOM also needs `phx-update="ignore"`.

## UI

- Icons: `<.icon name="hero-..." />`.
- Styling: Tailwind with daisyUI classes, as DESIGN.md prescribes. Do not use `@apply`.
- Colors: brand tokens are in DESIGN.md front matter and implemented in the daisyUI theme blocks in `assets/css/app.css`. Use role classes only; never hex values. Rail red never appears in UI code.
- Secondary text is `text-muted` (`placeholder:text-muted`, `border-muted`), never `text-base-content/40`–`/60`.
- Nothing below `text-xs` (12px). daisyUI's `btn-xs` sets 11px, so a `btn-xs` with visible text also gets `text-xs`. Page titles `text-2xl font-semibold`, section and modal titles `text-xl font-semibold`.
- Technical values (ports, versions, pins, raw numbers) get `font-mono`; other numeric readouts get `tabular-nums`.
- Confirms are `btn-primary` (or `btn-ghost` for cancel). Never `btn-success`; `btn-error` only for destructive confirms.
- Status uses soft variants (`alert alert-soft alert-*`, `badge badge-soft badge-*`, or `<.status_chip>`), always with a label: Connected, Connecting, Needs attention, Failed. Category badges are `badge-ghost`.
- No decorative `animate-pulse`, glows, gradients or halo rings. Any animation is `motion-safe:`; in-progress states use `hero-arrow-path-mini motion-safe:animate-spin` plus text.
- Never show `inspect(reason)` in the UI. Log it with `Logger` and show a plain sentence that explains the next step. Do not write "successfully".

## Routing

New app pages go in the `:default` `live_session`. It supplies the layout and the consent, nav and MCP detection hooks, so templates do not wrap themselves in a layout component.

## HTTP

Use `Req`.

## Edit-page sections

The hardware configuration page and the train page build every section from the primitives in `lib/trenino_web/components/shared_components.ex`. New sections use them too; `test/trenino_web/live/section_structure_test.exs` guards the structure.

- `<.config_section id title count description empty? empty_icon empty_message empty_hint>` is the card: `bg-base-200/50 rounded-xl`, an h3 title (`text-xl font-semibold`) with a `badge-ghost` count, `:actions` at the right, `:settings` as one muted row under the header, `:notice` for alerts, then the body. Never hand-roll the wrapper. Always pass `empty_message` when the section can be empty. LiveComponents render through it too, inside a plain `<div>` root.
- `<.section_empty>` is the only in-section empty state: one compact row (icon, message, hint). No plain `<p>` empty states. `<.empty_state>` is for full pages only.
- `<.section_action>` is the header button: `btn btn-outline btn-sm`, plus icon, label "Add {singular noun}" in sentence case. A disabled button gets a visible `disabled_reason`, linked with `aria-describedby`; when a `:notice` already explains the prerequisite (with links), pass its id as `describedby` instead, so the reason is not shown twice. Navigation actions pass `navigate` and render as real links; a disabled action is always a disabled button, even with `navigate`.
- `<.row_actions>` goes in the last table cell or the card corner. Non-destructive actions are ghost `btn-xs text-xs` with icon and text; pass `name` so their aria-labels say which item they act on ("Edit Horn"). Three or more collapse into a "..." menu (pass `id`), which closes on outside click and on Escape (the key binding sits on the summary and every menu item, since LiveView reads key bindings from the event target only); pass `menu={:always}` when optional actions come and go with the item's state, so the layout stays stable. Actions that go to another page use `navigate`, not `JS.navigate`. Delete is always last and visible: an icon-only trash with `label="Delete {name}"` (the aria-label) and `confirm="Delete {name}?"`, optionally with one sentence of consequence. Every delete confirms.
- `:notice` content: warnings and errors are `alert alert-soft alert-warning` / `alert-error` with a leading heroicon, as the gauge calibration panel's warning; plain muted text only for neutral prerequisite hints and short confirmations.
- On/off controls for an item's "enabled" state look like `toggle toggle-sm toggle-primary` with an aria-label naming the item. Use the checkbox toggle, or `<.switch>` when the server must confirm the change (it is styled to match). Never green: on is primary.
- Test buttons that keep state (an output's ON/OFF) get `aria-pressed` and an aria-label naming the item ("Test Horn").
- An unnamed item shows a muted "Unnamed" in its name cell, like the inline-name placeholders. Descriptive fallbacks ("display at 0x70") are for aria-labels and confirm text only.
- Field labels go through `<.input label=...>` (or a `<label for>`), never a sibling `<label class="label">`, so every control has an accessible name.
- Headings inside a section card rank below the section h3: card names are h4, panels and wizards inside a card are h5, their steps h6.
- Add modals are `max-w-md mx-4`, and the submit button repeats the title ("Add sequence").
- Lists are tables (`table table-sm`, actions column last). Cards only for lifecycle items (gauges and gauge bindings); sequences are a table. Status uses `<.status_chip>`.
- Section titles are sentence case. Sections in a group are siblings in `space-y-4`, each its own card. Groups use `<.section_group id title>` (a plain `div`, not a landmark, with an h2 group heading, `mt-8`, `space-y-4`); never hand-roll the group wrapper. The page has one h1 above the groups. `<.section_nav>` has one entry per section, labelled with the section title and counting what the section badge counts, from a private `nav_items/1`, and is hidden in new mode. Anchor targets inside a section (cards linked from other pages) get `scroll-mt-36` to clear the sticky header and nav.
- Section markup lives in `TreninoWeb.ConfigurationEditLive.Sections` / `.Modals` and `TreninoWeb.TrainEditLive.Sections`; `handle_event` and `handle_info` stay in the LiveViews, and data helpers (such as `Trenino.Hardware.Matrix.parse_pins/1`) live outside these markup modules. Modal titles are h2.
