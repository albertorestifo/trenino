defmodule TswIoWeb.SharedComponents do
  @moduledoc """
  Shared UI components used across multiple LiveViews.

  These components provide consistent styling and behavior for common
  UI patterns like modals, empty states, danger zones, and list cards.
  """

  use Phoenix.Component
  use TswIoWeb, :verified_routes

  import TswIoWeb.CoreComponents

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
      <div class="relative bg-base-100 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-lg font-semibold mb-4">{@title}</h3>

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
        title="Delete Train"
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
      <div class="relative bg-base-100 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-lg font-semibold mb-4 text-error">{@title}</h3>

        <div :if={@is_active && @active_warning} class="alert alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-sm">{@active_warning}</span>
        </div>

        <p class="text-sm text-base-content/70 mb-6">
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
      <p class="mt-2 text-base-content/70 max-w-sm">
        {@description}
      </p>
      <.link :if={@action_path} navigate={@action_path} class="btn btn-primary mt-6">
        <.icon name={@action_icon} class="w-4 h-4" /> {@action_text}
      </.link>
    </div>
    """
  end

  @doc """
  A smaller empty state for use within sections.

  ## Examples

      <.empty_collection_state
        icon="hero-adjustments-horizontal"
        message="No elements configured"
        submessage="Add elements to control train functions"
      />

  """
  attr :icon, :string, required: true
  attr :message, :string, required: true
  attr :submessage, :string, default: nil

  def empty_collection_state(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-lg p-8 text-center">
      <.icon name={@icon} class="w-10 h-10 mx-auto text-base-content/30" />
      <p class="mt-2 text-sm text-base-content/70">{@message}</p>
      <p :if={@submessage} class="text-xs text-base-content/50">{@submessage}</p>
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
        action_label="Delete Train"
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
      <h3 class="text-sm font-semibold text-error mb-4">{@title}</h3>
      <div class="p-4 rounded-lg border border-error/30 bg-error/5">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="font-medium text-sm">{@action_label}</p>
            <p class="text-xs text-base-content/70 mt-1">{@action_description}</p>
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
        metadata={[train.identifier, "3 elements"]}
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
            <h3 class="font-medium truncate group-hover:text-primary transition-colors">
              {@title}
            </h3>
            <span
              :if={@active}
              class="badge badge-success badge-sm flex items-center gap-1"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-success-content animate-pulse" /> Active
            </span>
          </div>
          <p :if={@description} class="text-sm text-base-content/70 mt-1 line-clamp-2">
            {@description}
          </p>
          <div :if={@metadata != []} class="mt-2 flex items-center gap-4 text-xs text-base-content/60">
            <span :for={item <- @metadata} class="font-mono">{item}</span>
          </div>
        </div>

        <.icon
          name="hero-chevron-right"
          class="w-5 h-5 text-base-content/30 group-hover:text-base-content/50 transition-colors flex-shrink-0"
        />
      </div>
    </.link>
    """
  end

  # ===================
  # Section Header Component
  # ===================

  @doc """
  A section header with title and optional action button.

  Used for consistent section styling across edit pages (Elements, Sequences, Inputs, Outputs).

  ## Examples

      <.section_header title="Elements" action_label="Add Element" on_action="open_add_element_modal" />

      <.section_header title="Sequences" action_label="New Sequence" on_action="open_add_modal" target={@myself} />

  """
  attr :title, :string, required: true
  attr :action_label, :string, default: nil
  attr :on_action, :string, default: nil
  attr :target, :any, default: nil

  def section_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-base font-semibold">{@title}</h3>
      <button
        :if={@action_label && @on_action}
        phx-click={@on_action}
        phx-target={@target}
        class="btn btn-outline btn-sm"
      >
        <.icon name="hero-plus" class="w-4 h-4" /> {@action_label}
      </button>
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
    <header class="mb-8 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold">{@title}</h1>
        <p class="text-sm text-base-content/70 mt-1">{@subtitle}</p>
      </div>
      <.link :if={@action_path} navigate={@action_path} class="btn btn-primary">
        <.icon name={@action_icon} class="w-4 h-4" /> {@action_text}
      </.link>
    </header>
    """
  end
end
