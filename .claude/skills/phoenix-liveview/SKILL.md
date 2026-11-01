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

## Routing

New app pages go in the `:default` `live_session`. It supplies the layout and the consent, nav and MCP detection hooks, so templates do not wrap themselves in a layout component.

## HTTP

Use `Req`.
