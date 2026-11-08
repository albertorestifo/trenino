defmodule TreninoWeb.SharedComponents do
  @moduledoc """
  Shared UI components used across multiple LiveViews.

  These components provide consistent styling and behavior for common
  UI patterns like modals, empty states, danger zones, and list cards.
  """

  use Phoenix.Component
  use TreninoWeb, :verified_routes

  import TreninoWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # ===================
  # Modal Components
  # ===================

  @doc """
  A basic modal wrapper with backdrop and close functionality.

  ## Examples

      <.modal on_close="close_modal" title="Add Element">
        <.form for={@form} phx-submit="add_element">
          ...
        </.form>
      </.modal>

  """
  attr :on_close, :string, required: true
  attr :title, :string, required: true

  slot :inner_block, required: true
  slot :actions

  def modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click={@on_close} />
      <div class="relative bg-base-200 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-xl font-semibold mb-4">{@title}</h3>

        {render_slot(@inner_block)}

        <div :if={@actions != []} class="flex justify-end gap-2 mt-6">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  A confirmation modal for dangerous actions like deletion.

  ## Examples

      <.confirmation_modal
        on_close="close_delete_modal"
        on_confirm="confirm_delete"
        title="Delete train"
        item_name={@train.name}
        description="This will permanently delete the train and all its data."
        is_active={@is_active}
        active_warning="This train is currently active in the simulator."
      />

  """
  attr :on_close, :string, required: true
  attr :on_confirm, :string, required: true
  attr :title, :string, required: true
  attr :item_name, :string, required: true
  attr :description, :string, required: true
  attr :is_active, :boolean, default: false
  attr :active_warning, :string, default: nil

  def confirmation_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click={@on_close} />
      <div class="relative bg-base-200 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-xl font-semibold mb-4 text-error">{@title}</h3>

        <div :if={@is_active && @active_warning} class="alert alert-soft alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-sm">{@active_warning}</span>
        </div>

        <p class="text-sm text-muted mb-6">
          Are you sure you want to delete "<span class="font-medium">{@item_name}</span>"? {@description}
        </p>

        <div class="flex justify-end gap-2">
          <button type="button" phx-click={@on_close} class="btn btn-ghost">
            Cancel
          </button>
          <button
            :if={not @is_active}
            type="button"
            phx-click={@on_confirm}
            class="btn btn-error"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ===================
  # Empty State Components
  # ===================

  @doc """
  A full-page empty state with icon, heading, description, and optional action.

  ## Examples

      <.empty_state
        icon="hero-truck"
        heading="No Train Configurations"
        description="Create a train configuration to set up controls."
        action_path={~p"/trains/new"}
        action_text="Create Train Configuration"
      />

  """
  attr :icon, :string, required: true
  attr :heading, :string, required: true
  attr :description, :string, required: true
  attr :action_path, :string, default: nil
  attr :action_text, :string, default: nil
  attr :action_icon, :string, default: "hero-plus"

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <.icon name={@icon} class="w-16 h-16 text-base-content/20" />
      <h2 class="mt-6 text-xl font-semibold">{@heading}</h2>
      <p class="mt-2 text-muted max-w-sm">
        {@description}
      </p>
      <.link :if={@action_path} navigate={@action_path} class="btn btn-primary mt-6">
        <.icon name={@action_icon} class="w-4 h-4" /> {@action_text}
      </.link>
    </div>
    """
  end

  # ===================
  # Danger Zone Component
  # ===================

  @doc """
  A danger zone section for destructive actions.

  ## Examples

      <.danger_zone
        action_label="Delete train"
        action_description="Permanently remove this train and all associated data"
        on_action="show_delete_modal"
        disabled={@is_active}
        disabled_reason="Cannot delete while train is currently active"
      />

  """
  attr :title, :string, default: "Danger Zone"
  attr :action_label, :string, required: true
  attr :action_description, :string, required: true
  attr :on_action, :string, required: true
  attr :disabled, :boolean, default: false
  attr :disabled_reason, :string, default: nil

  def danger_zone(assigns) do
    ~H"""
    <div class="mt-12 pt-8 border-t border-base-300">
      <h2 class="text-sm font-semibold text-error mb-4">{@title}</h2>
      <div class="p-4 rounded-lg border border-error/30 bg-error/5">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="font-medium text-sm">{@action_label}</p>
            <p class="text-xs text-muted mt-1">{@action_description}</p>
          </div>
          <button
            type="button"
            phx-click={@on_action}
            disabled={@disabled}
            class="btn btn-error btn-sm"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Delete
          </button>
        </div>
        <p :if={@disabled && @disabled_reason} class="text-xs text-warning mt-3">
          <.icon name="hero-exclamation-triangle" class="w-4 h-4 inline" />
          {@disabled_reason}
        </p>
      </div>
    </div>
    """
  end

  # ===================
  # List Card Component
  # ===================

  @doc """
  A card component for list views with hover effects and active state.

  ## Examples

      <.list_card
        active={train.id == @active_train_id}
        navigate_to={~p"/trains/\#{train.id}"}
        title={train.name}
        description={train.description}
        metadata={Train.identifier_values(train) ++ ["3 elements"]}
      />

  """
  attr :active, :boolean, default: false
  attr :navigate_to, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :metadata, :list, default: []

  def list_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate_to}
      class={[
        "block rounded-xl transition-colors group cursor-pointer",
        if(@active,
          do: "border-2 border-success bg-success/5",
          else: "border border-base-300 bg-base-200/50 hover:bg-base-200"
        )
      ]}
    >
      <div class="flex items-start justify-between gap-4 p-5">
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <h2 class="font-medium truncate transition-colors">
              {@title}
            </h2>
            <.status_chip :if={@active} kind={:ok} label="Active" />
          </div>
          <p :if={@description} class="text-sm text-muted mt-1 line-clamp-2">
            {@description}
          </p>
          <div :if={@metadata != []} class="mt-2 flex items-center gap-4 text-xs text-muted">
            <span :for={item <- @metadata} class="font-mono">{item}</span>
          </div>
        </div>

        <.icon
          name="hero-chevron-right"
          class="w-5 h-5 text-muted group-hover:text-base-content transition-colors flex-shrink-0"
        />
      </div>
    </.link>
    """
  end

  # ===================
  # Edit-page Section Components
  # ===================

  @doc """
  A card for one section of an edit page (hardware configuration, train).

  Renders the title as an `h3` with an optional count badge, the `:actions` slot on the
  right of the header, an optional one-line description, the `:settings` slot as a quiet
  row directly under the header, the `:notice` slot for alerts, and then either the body
  (`:inner_block`) or a compact `section_empty/1` when `empty?` is true.

  The `id` doubles as the anchor target for `section_nav/1`.

  ## Examples

      <.config_section
        id="inputs"
        title="Inputs"
        count={length(@inputs)}
        description="Analog and digital pins read by the device."
        empty?={@inputs == []}
        empty_icon="hero-adjustments-horizontal"
        empty_message="No inputs yet"
        empty_hint="Add an input to start reading a pin."
      >
        <:actions>
          <.section_action id="add-input" label="Add input" on_click="open_add_input_modal" />
        </:actions>
        <:settings>
          Motor shield address <span class="font-mono">0x60</span>
        </:settings>
        <:notice>
          <div class="alert alert-soft alert-warning">Apply the configuration to use it.</div>
        </:notice>
        <table class="table table-sm">...</table>
      </.config_section>

  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :description, :string, default: nil
  attr :empty?, :boolean, default: false
  attr :empty_icon, :string, default: "hero-inbox"
  attr :empty_message, :string, default: nil
  attr :empty_hint, :string, default: nil
  attr :class, :any, default: nil

  slot :actions
  slot :settings
  slot :notice
  slot :inner_block

  def config_section(assigns) do
    ~H"""
    <section
      id={@id}
      aria-labelledby={"#{@id}-title"}
      data-section-card
      class={["bg-base-200/50 rounded-xl p-4 sm:p-6 scroll-mt-36", @class]}
    >
      <div class="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h3 id={"#{@id}-title"} class="text-xl font-semibold">{@title}</h3>
            <span
              :if={is_integer(@count) and @count > 0}
              class="badge badge-ghost tabular-nums"
            >
              {@count}
            </span>
          </div>
          <p :if={@description} class="text-sm text-muted mt-1">{@description}</p>
        </div>
        <div :if={@actions != []} class="flex shrink-0 items-start gap-2">
          {render_slot(@actions)}
        </div>
      </div>

      <div
        :if={@settings != []}
        class="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted"
      >
        {render_slot(@settings)}
      </div>

      <div :if={@notice != []} class="mt-4 space-y-2">
        {render_slot(@notice)}
      </div>

      <div class="mt-4">
        <%= if @empty? do %>
          <.section_empty icon={@empty_icon} message={@empty_message} hint={@empty_hint} />
        <% else %>
          {render_slot(@inner_block)}
        <% end %>
      </div>
    </section>
    """
  end

  @doc """
  The compact empty state used inside a `config_section/1`.

  A single quiet row: icon, message, and an optional hint that says what to do next.
  For a full-page empty state use `empty_state/1` instead.

  ## Examples

      <.section_empty
        icon="hero-cpu-chip"
        message="No elements yet"
        hint="Add an element to bind a control in the simulator."
      />

  """
  attr :icon, :string, default: "hero-inbox"
  attr :message, :string, required: true
  attr :hint, :string, default: nil

  def section_empty(assigns) do
    ~H"""
    <div data-section-empty class="bg-base-100 rounded-lg px-4 py-3 flex items-center gap-3">
      <.icon name={@icon} class="size-5 shrink-0 text-muted" />
      <div class="min-w-0">
        <p class="text-sm">{@message}</p>
        <p :if={@hint} class="text-xs text-muted">{@hint}</p>
      </div>
    </div>
    """
  end

  @doc """
  The add (or other primary) action in a `config_section/1` header.

  When `disabled` and `disabled_reason` are both set, the reason is shown as visible
  text next to the button and linked to it with `aria-describedby`. When the section
  already explains the prerequisite visibly (for example a notice with links), pass that
  element's id as `describedby` instead of repeating the text in `disabled_reason`.

  With `navigate` set the action is a real link (`<.link navigate>`), so it can be
  opened in a new tab and is announced as a link. A disabled action is always a
  disabled button, even with `navigate` set, so it can never be followed.

  ## Examples

      <.section_action id="add-element" label="Add element" on_click="open_add_element_modal" />

      <.section_action id="add-script" label="Add script" navigate={~p"/trains/1/scripts/new"} />

      <.section_action
        id="add-sequence"
        label="Add sequence"
        on_click="open_add_modal"
        target={@myself}
        disabled={not @connected}
        disabled_reason="Connect the simulator to add a sequence."
      />

  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :on_click, :any, default: nil, doc: "an event name or a `Phoenix.LiveView.JS` command"
  attr :navigate, :string, default: nil, doc: "renders a `<.link navigate>` instead of a button"
  attr :target, :any, default: nil
  attr :icon, :string, default: "hero-plus"
  attr :disabled, :boolean, default: false
  attr :disabled_reason, :string, default: nil

  attr :describedby, :string,
    default: nil,
    doc: "id of a visible explanation elsewhere in the section, used when disabled"

  def section_action(assigns) do
    reason_id = if(assigns.disabled && assigns.disabled_reason, do: "#{assigns.id}-reason")

    assigns =
      assigns
      |> assign(:reason_id, reason_id)
      |> assign(:describedby_id, reason_id || (assigns.disabled && assigns.describedby) || nil)

    ~H"""
    <div class="flex flex-col items-end gap-1">
      <.link
        :if={@navigate && !@disabled}
        id={@id}
        navigate={@navigate}
        class="btn btn-outline btn-sm"
      >
        <.icon name={@icon} class="size-4" /> {@label}
      </.link>
      <button
        :if={is_nil(@navigate) or @disabled}
        id={@id}
        type="button"
        phx-click={@on_click}
        phx-target={@target}
        disabled={@disabled}
        aria-describedby={@describedby_id}
        class="btn btn-outline btn-sm"
      >
        <.icon name={@icon} class="size-4" /> {@label}
      </button>
      <p :if={@reason_id} id={@reason_id} class="text-xs text-muted text-right max-w-64">
        {@disabled_reason}
      </p>
    </div>
    """
  end

  @doc """
  The actions for one table row or card, right-aligned.

  Non-destructive actions (`kind` other than `:danger`) render as small ghost buttons
  with icon and text. When there are three or more of them they collapse into a "..."
  menu; pass `menu={:always}` to keep them in the menu whatever their number (for cards
  whose optional actions come and go with their state, so the layout stays stable).
  An action with `navigate` renders as a real link instead of a button, and one with
  `href` as an external link that opens in the browser. A disabled action can say why
  in `title`. Labels render
  at `text-xs` (12px); daisyUI's `btn-xs` alone would make them 11px. When `name` is
  set, inline actions get `"{label} {name}"` as their aria-label, so a screen reader's
  list of buttons says which item each "Edit" or "Test" belongs to.

  The overflow menu closes on a click outside it and on Escape (which returns focus to
  its "..." button), as well as after one of its items is clicked.

  Destructive actions always render last, outside the menu, as an icon-only
  trash button whose `label` becomes its `aria-label` and which always carries
  `data-confirm` (defaulting to `"{label}?"`).

  ## Examples

      <.row_actions id={"input-actions-\#{input.id}"} name={input.name}>
        <:action event="calibrate" values={%{id: input.id}} icon="hero-adjustments-vertical" label="Calibrate" />
        <:action
          event="delete_input"
          values={%{id: input.id}}
          label={"Delete \#{input.name}"}
          kind={:danger}
          confirm={"Delete \#{input.name}?"}
        />
      </.row_actions>

  """
  attr :id, :string,
    default: nil,
    doc: "DOM id of the wrapper; the overflow menu uses `{id}-menu`"

  attr :menu_id, :string,
    default: nil,
    doc: "DOM id of the overflow menu; defaults to `{id}-menu`"

  attr :name, :string,
    default: nil,
    doc: "item name, added to the aria-labels of the inline actions and the overflow menu"

  attr :class, :any, default: nil

  attr :menu, :atom,
    default: :auto,
    values: [:auto, :always],
    doc: "`:auto` collapses three or more regular actions into the menu, `:always` always does"

  slot :action do
    attr :event, :any, doc: "an event name or a `Phoenix.LiveView.JS` command"
    attr :navigate, :string, doc: "renders a `<.link navigate>` instead of a button"
    attr :href, :string, doc: "renders an external link that opens in a new window"
    attr :title, :string, doc: "tooltip, e.g. why the action is disabled"
    attr :values, :map, doc: "sent as `phx-value-*`"
    attr :icon, :string
    attr :label, :string, required: true
    attr :kind, :atom, values: [:default, :danger]
    attr :confirm, :string
    attr :target, :any
    attr :id, :string
    attr :disabled, :boolean
  end

  def row_actions(assigns) do
    {danger, regular} = Enum.split_with(assigns.action, &(&1[:kind] == :danger))

    assigns =
      assigns
      |> assign(:danger, danger)
      |> assign(:regular, regular)
      |> assign(:overflow?, regular != [] and (assigns.menu == :always or length(regular) >= 3))
      |> assign(:menu_id, assigns.menu_id || (assigns.id && "#{assigns.id}-menu"))

    ~H"""
    <div id={@id} class={["flex items-center justify-end gap-1", @class]}>
      <%= if @overflow? do %>
        <details
          id={@menu_id}
          phx-mounted={JS.ignore_attributes("open")}
          phx-click-away={JS.remove_attribute("open")}
          class="dropdown dropdown-end"
        >
          <summary
            phx-keydown={close_menu()}
            phx-key="Escape"
            aria-label={if(@name, do: "More actions for #{@name}", else: "More actions")}
            class="btn btn-ghost btn-xs list-none"
          >
            <.icon name="hero-ellipsis-horizontal" class="size-4" />
          </summary>
          <ul class="menu dropdown-content z-10 mt-1 w-56 rounded-box border border-base-300 bg-base-200 p-1 shadow">
            <li :for={action <- @regular}>
              <.link
                :if={action[:navigate]}
                id={action[:id]}
                navigate={action.navigate}
                phx-keydown={close_menu()}
                phx-key="Escape"
              >
                <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
                {action.label}
              </.link>
              <a
                :if={action[:href]}
                id={action[:id]}
                href={action.href}
                target="_blank"
                rel="noopener noreferrer"
                title={action[:title]}
                phx-click={close_menu()}
                phx-keydown={close_menu()}
                phx-key="Escape"
              >
                <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
                {action.label}<span class="sr-only"> (opens in new tab)</span>
              </a>
              <button
                :if={is_nil(action[:navigate]) and is_nil(action[:href])}
                id={action[:id]}
                type="button"
                title={action[:title]}
                phx-click={menu_click(action)}
                phx-keydown={close_menu()}
                phx-key="Escape"
                disabled={action[:disabled] || false}
                data-confirm={action[:confirm]}
                {phx_values(action)}
              >
                <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
                {action.label}
              </button>
            </li>
          </ul>
        </details>
      <% else %>
        <%= for action <- @regular do %>
          <.link
            :if={action[:navigate]}
            id={action[:id]}
            navigate={action.navigate}
            aria-label={action_aria_label(action, @name)}
            class="btn btn-ghost btn-xs text-xs"
          >
            <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
            {action.label}
          </.link>
          <a
            :if={action[:href]}
            id={action[:id]}
            href={action.href}
            target="_blank"
            rel="noopener noreferrer"
            title={action[:title]}
            aria-label={action_aria_label(action, @name) <> " (opens in new tab)"}
            class="btn btn-ghost btn-xs text-xs"
          >
            <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
            {action.label}
          </a>
          <button
            :if={is_nil(action[:navigate]) and is_nil(action[:href])}
            id={action[:id]}
            type="button"
            title={action[:title]}
            phx-click={action[:event]}
            phx-target={action[:target]}
            disabled={action[:disabled] || false}
            data-confirm={action[:confirm]}
            aria-label={action_aria_label(action, @name)}
            class="btn btn-ghost btn-xs text-xs"
            {phx_values(action)}
          >
            <.icon :if={action[:icon]} name={action[:icon]} class="size-4" />
            {action.label}
          </button>
        <% end %>
      <% end %>
      <button
        :for={action <- @danger}
        id={action[:id]}
        type="button"
        phx-click={action[:event]}
        phx-target={action[:target]}
        disabled={action[:disabled] || false}
        data-confirm={action[:confirm] || "#{action.label}?"}
        aria-label={action.label}
        title={action.label}
        class="btn btn-ghost btn-xs text-error"
        {phx_values(action)}
      >
        <.icon name="hero-trash" class="size-4" />
      </button>
    </div>
    """
  end

  defp action_aria_label(action, nil), do: action.label
  defp action_aria_label(action, name), do: "#{action.label} #{name}"

  defp phx_values(action) do
    action
    |> Map.get(:values, %{})
    |> Kernel.||(%{})
    |> Enum.map(fn {key, value} -> {"phx-value-#{key}", value} end)
  end

  # Runs the action, then closes the overflow menu it was clicked in.
  defp menu_click(action) do
    action[:event]
    |> menu_push(action[:target])
    |> JS.remove_attribute("open", to: {:closest, "details"})
  end

  # LiveView reads key bindings from the event target only (they do not bubble), so
  # this sits on the summary and on every menu item: whichever has focus closes the
  # menu and hands focus back to the "..." summary, the first focusable child.
  defp close_menu do
    JS.remove_attribute("open", to: {:closest, "details"})
    |> JS.focus_first(to: {:closest, "details"})
  end

  defp menu_push(%JS{} = js, _target), do: js
  # A disabled item with no event (e.g. an external link that is not available yet)
  defp menu_push(nil, _target), do: %JS{}
  defp menu_push(event, nil), do: JS.push(event)
  defp menu_push(event, target), do: JS.push(event, target: target)

  @doc """
  A sticky row of anchor links to the sections of an edit page, one per section, each
  labelled with the section title and counting what the section's badge counts.

  Each item is `%{id: "inputs", label: "Inputs", count: 3}`; `count` is optional and
  hidden when nil or zero. Hide the nav in new mode with `:if`.

  The nav sticks only from `md` up, at `top-19` (76px), just under the app header
  (about 79px tall there, so the header overlaps the nav's top padding rather than
  leaving a gap). Below `md` the app header wraps onto two rows (up to about 134px)
  and a pinned nav would cover a large part of a phone screen, so the nav scrolls
  with the page. Section targets use `scroll-mt-36`, which clears header plus nav.

  ## Examples

      <.section_nav
        :if={not @new_mode}
        label="Hardware configuration sections"
        items={[
          %{id: "inputs", label: "Inputs", count: length(@inputs)},
          %{id: "matrices", label: "Matrices", count: length(@matrices)}
        ]}
      />

  """
  attr :id, :string, default: "section-nav"
  attr :label, :string, default: "Page sections"

  attr :items, :list,
    required: true,
    doc: "list of `%{id: String.t(), label: String.t(), count: integer() | nil}`"

  attr :class, :any, default: nil

  def section_nav(assigns) do
    ~H"""
    <nav
      id={@id}
      aria-label={@label}
      class={[
        "md:sticky md:top-19 z-10 bg-base-100 border-b border-base-300 py-2 flex flex-wrap gap-1",
        @class
      ]}
    >
      <a :for={item <- @items} href={"##{item.id}"} class="btn btn-ghost btn-sm">
        {item.label}
        <span
          :if={is_integer(item[:count]) and item[:count] > 0}
          class="badge badge-ghost badge-sm tabular-nums"
        >
          {item[:count]}
        </span>
      </a>
    </nav>
    """
  end

  @doc """
  A group of `config_section/1` cards on an edit page, under an `h2` group heading.

  The `id` is the anchor target for `section_nav/1` and the heading gets `{id}-title`.
  The group is a plain `div`, not a landmark: its sections are the named regions, and a
  group often shares its name with its first section ("Inputs" holds "Inputs").

  ## Examples

      <.section_group id="inputs-group" title="Inputs">
        <.inputs_section inputs={@inputs} />
        <.matrices_section matrices={@matrices} />
      </.section_group>

  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def section_group(assigns) do
    ~H"""
    <div id={@id} data-section-group class="scroll-mt-36 mt-8">
      <h2 id={"#{@id}-title"} class="text-sm font-semibold uppercase tracking-wide text-muted mb-3">
        {@title}
      </h2>
      <div class="space-y-4">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ===================
  # Page Header Component
  # ===================

  @doc """
  A standard page header with title, subtitle, and action button.

  ## Examples

      <.page_header
        title="Trains"
        subtitle="Manage train configurations"
        action_path={~p"/trains/new"}
        action_text="New Train"
      />

  """
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :action_path, :string, default: nil
  attr :action_text, :string, default: nil
  attr :action_icon, :string, default: "hero-plus"

  def page_header(assigns) do
    ~H"""
    <header class="mb-8 flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-semibold">{@title}</h1>
        <p class="text-sm text-muted mt-1">{@subtitle}</p>
      </div>
      <.link :if={@action_path} navigate={@action_path} class="btn btn-primary">
        <.icon name={@action_icon} class="w-4 h-4" /> {@action_text}
      </.link>
    </header>
    """
  end
end
