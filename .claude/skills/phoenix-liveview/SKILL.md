---
name: phoenix-liveview
description: Use when writing Phoenix controllers, LiveView modules, HEEx templates, Ecto queries, forms, routing, or frontend assets (Tailwind v4, esbuild) in this project. Also use when writing LiveView tests, working with streams, or handling UI/UX decisions.
---

# Phoenix + LiveView Guidelines

## HTTP Client

Use `:req` (`Req`) for HTTP requests. **Never** use `:httpoison`, `:tesla`, or `:httpc`.

## Phoenix Router

- `scope` blocks include an optional alias prefixed to all routes within — never create your own `alias` for route definitions
- `Phoenix.View` is no longer included — do not use it

## LiveView Layouts

**Always** begin LiveView templates with `<Layouts.app flash={@flash} ...>`. `MyAppWeb.Layouts` is already aliased in `myappweb.ex`.

- `<.flash_group>` is **forbidden** outside of `layouts.ex`
- "no `current_scope` assign" errors: move the route to the correct `live_session` and pass `current_scope` to `<Layouts.app>`

## Icons and Components

- **Always** use `<.icon name="hero-x-mark" class="w-5 h-5"/>` for icons
- **Always** use `<.input>` for form inputs from `core_components.ex`

## HEEx Templates

- `{...}` for tag attributes and simple value interpolation in tag bodies
- `<%= ... %>` for block constructs (`if`, `cond`, `case`, `for`) in tag bodies
- **Never** use `<%= %>` inside tag attributes — raises a syntax error
- HEEx comments: `<%!-- comment --%>`
- `phx-no-curly-interpolation` on tags containing literal `{` `}` characters

```heex
<%!-- VALID --%>
<div id={@id}>
  {@value}
  <%= if @cond do %>{@other}<% end %>
</div>

<%!-- INVALID — never do this --%>
<div id="<%= @id %>">
  {if @cond do}{end}
</div>
```

Class lists — always use `[...]`:

```heex
<a class={["px-2", @flag && "py-5", if(@cond, do: "red", else: "blue")]}>
```

- **Never** `<% Enum.each %>` — use `<%= for item <- @collection do %>`
- `if/else if` does not exist — use `cond` or `case`

## LiveView

- Name with `Live` suffix: `AppWeb.WeatherLive`; `:browser` scope is already aliased with `AppWeb`
- **Never** use `live_redirect` / `live_patch` — use `<.link navigate>` / `<.link patch>` and `push_navigate` / `push_patch`
- **Avoid LiveComponents** unless there is a strong specific need
- `phx-hook` managing its own DOM **must** also have `phx-update="ignore"`
- **Never** write `<script>` tags in HEEx — always use `assets/js/`

### Streams

Always use streams for collections:

```elixir
stream(socket, :messages, [msg])                      # append
stream(socket, :messages, msgs, reset: true)           # reset/filter
stream(socket, :messages, [msg], at: -1)              # prepend
stream_delete(socket, :messages, msg)                 # delete
```

```heex
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>{msg.text}</div>
</div>
```

Streams are **not enumerable** — to filter, refetch and re-stream with `reset: true`. Track count/empty state with a separate assign. **Never** use `phx-update="append"` or `phx-update="prepend"`.

### Forms

```elixir
assign(socket, form: to_form(changeset))
assign(socket, form: to_form(params, as: :user))
```

```heex
<%!-- ALWAYS --%>
<.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:field]} type="text" />
</.form>
```

- **Never** pass a changeset directly to the template
- **Never** use `<.form let={f} ...>` — always `<.form for={@form} ...>`
- Always give forms an explicit unique DOM ID

### LiveView Tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` for assertions
- **Never** test raw HTML — always use `element/2`, `has_element/2`
- Always reference the DOM IDs you added in the LiveView
- Debug: `LazyHTML.filter(LazyHTML.from_fragment(render(view)), "selector")`

## Ecto

- Always preload associations before accessing them in templates
- `Ecto.Schema` fields use `:string` even for text columns
- Always use `Ecto.Changeset.get_field(changeset, :field)` — never map access syntax on structs
- Fields set programmatically (`user_id`) must **not** be in `cast`

## Tailwind CSS v4

```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/my_app_web";
```

- **Never** use `@apply` in raw CSS
- **Always** write Tailwind-based components manually — never use daisyUI
- No `tailwind.config.js` needed in v4

## Frontend Assets

Only `app.js` and `app.css` bundles are supported — import vendor deps into them. **Never** write inline `<script>` tags in templates.

## UI/UX Design

Produce world-class UI with subtle micro-interactions, clean typography, and delightful details (hover effects, loading states, smooth transitions).
