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
- Nothing below `text-xs` (12px). Page titles `text-2xl font-semibold`, section and modal titles `text-xl font-semibold`.
- Technical values (ports, versions, pins, raw numbers) get `font-mono`; other numeric readouts get `tabular-nums`.
- Confirms are `btn-primary` (or `btn-ghost` for cancel). Never `btn-success`; `btn-error` only for destructive confirms.
- Status uses soft variants (`alert alert-soft alert-*`, `badge badge-soft badge-*`, or `<.status_chip>`), always with a label: Connected, Connecting, Needs attention, Failed. Category badges are `badge-ghost`.
- No decorative `animate-pulse`, glows, gradients or halo rings. Any animation is `motion-safe:`; in-progress states use `hero-arrow-path-mini motion-safe:animate-spin` plus text.
- Never show `inspect(reason)` in the UI. Log it with `Logger` and show a plain sentence that explains the next step. Do not write "successfully".

## Routing

New app pages go in the `:default` `live_session`. It supplies the layout and the consent, nav and MCP detection hooks, so templates do not wrap themselves in a layout component.

## HTTP

Use `Req`.
