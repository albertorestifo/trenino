defmodule TswIoWeb.MatrixTestWizard do
  @moduledoc """
  LiveComponent for testing matrix button inputs.

  Displays a visual grid of all matrix button positions.
  Buttons light up when pressed and change color once pressed at least once.
  This allows testing of matrix wiring to verify all buttons work.

  ## Usage

      <.live_component
        module={TswIoWeb.MatrixTestWizard}
        id="matrix-test-wizard"
        input={@testing_matrix_input}
        port={@active_port}
        input_values={@input_values}
        tested_buttons={@matrix_tested_buttons}
      />

  The parent LiveView must:
  - Track `matrix_tested_buttons` (a MapSet of virtual pins pressed at least once)
  - Pass `input_values` which contains current pin values
  - Handle `:reset_matrix_test` message to clear tested_buttons
  - Handle `:close_matrix_test` message to close the modal
  """

  use TswIoWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:rows, [])
     |> assign(:cols, [])}
  end

  @impl true
  def update(%{matrix: matrix} = assigns, socket) do
    rows = matrix.row_pins |> Enum.sort_by(& &1.position)
    cols = matrix.col_pins |> Enum.sort_by(& &1.position)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:rows, rows)
     |> assign(:cols, cols)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_matrix_test)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    send(self(), :reset_matrix_test)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    num_rows = length(assigns.rows)
    num_cols = length(assigns.cols)
    total_buttons = num_rows * num_cols
    tested_count = MapSet.size(assigns.tested_buttons)

    # Compute currently pressed buttons from input_values
    # Virtual pins start at 128
    pressed_buttons =
      assigns.input_values
      |> Enum.filter(fn {pin, value} -> pin >= 128 and value == 1 end)
      |> Enum.map(fn {pin, _} -> pin end)
      |> MapSet.new()

    progress_percent =
      if total_buttons > 0 do
        Float.round(tested_count / total_buttons * 100, 0)
      else
        0.0
      end

    assigns =
      assigns
      |> assign(:num_rows, num_rows)
      |> assign(:num_cols, num_cols)
      |> assign(:total_buttons, total_buttons)
      |> assign(:tested_count, tested_count)
      |> assign(:progress_percent, progress_percent)
      |> assign(:pressed_buttons, pressed_buttons)

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-2xl mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <.wizard_header
          num_rows={@num_rows}
          num_cols={@num_cols}
          target={@myself}
        />

        <.progress_bar
          tested_count={@tested_count}
          total_buttons={@total_buttons}
          progress_percent={@progress_percent}
        />

        <.button_grid
          :if={@num_rows > 0 and @num_cols > 0}
          rows={@rows}
          cols={@cols}
          num_cols={@num_cols}
          pressed_buttons={@pressed_buttons}
          tested_buttons={@tested_buttons}
        />

        <.empty_state :if={@num_rows == 0 or @num_cols == 0} />

        <.legend />

        <.action_buttons myself={@myself} />
      </div>
    </div>
    """
  end

  # Components

  attr :num_rows, :integer, required: true
  attr :num_cols, :integer, required: true
  attr :target, :any, required: true

  defp wizard_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-4">
      <div>
        <h2 class="text-xl font-semibold">Test Matrix</h2>
        <p class="text-sm text-base-content/70">{@num_rows} rows x {@num_cols} columns</p>
      </div>
      <button
        phx-click="close"
        phx-target={@target}
        class="btn btn-ghost btn-sm btn-circle"
        aria-label="Close"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end

  attr :tested_count, :integer, required: true
  attr :total_buttons, :integer, required: true
  attr :progress_percent, :float, required: true

  defp progress_bar(assigns) do
    ~H"""
    <div class="mb-6">
      <div class="flex items-center justify-between text-sm mb-2">
        <span class="text-base-content/70">Progress</span>
        <span class="font-medium">
          {@tested_count} / {@total_buttons} buttons tested
          <span class="text-base-content/50">({trunc(@progress_percent)}%)</span>
        </span>
      </div>
      <div class="w-full bg-base-300 rounded-full h-2">
        <div
          class="bg-success h-2 rounded-full transition-all duration-300"
          style={"width: #{@progress_percent}%"}
        />
      </div>
    </div>
    """
  end

  attr :rows, :list, required: true
  attr :cols, :list, required: true
  attr :num_cols, :integer, required: true
  attr :pressed_buttons, :any, required: true
  attr :tested_buttons, :any, required: true

  defp button_grid(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
      <table class="mx-auto">
        <thead>
          <tr>
            <th class="p-1"></th>
            <th
              :for={{col, col_idx} <- Enum.with_index(@cols)}
              class="p-1 text-center text-xs font-mono text-base-content/70"
            >
              C{col_idx}
              <br />
              <span class="text-[10px]">({col.pin})</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{row, row_idx} <- Enum.with_index(@rows)}>
            <td class="p-1 text-xs font-mono text-base-content/70 text-right pr-2">
              R{row_idx} <span class="text-[10px]">({row.pin})</span>
            </td>
            <td :for={{_col, col_idx} <- Enum.with_index(@cols)} class="p-1">
              <.matrix_button
                row_idx={row_idx}
                col_idx={col_idx}
                num_cols={@num_cols}
                pressed_buttons={@pressed_buttons}
                tested_buttons={@tested_buttons}
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :row_idx, :integer, required: true
  attr :col_idx, :integer, required: true
  attr :num_cols, :integer, required: true
  attr :pressed_buttons, :any, required: true
  attr :tested_buttons, :any, required: true

  defp matrix_button(assigns) do
    virtual_pin = 128 + assigns.row_idx * assigns.num_cols + assigns.col_idx
    pressed = MapSet.member?(assigns.pressed_buttons, virtual_pin)
    tested = MapSet.member?(assigns.tested_buttons, virtual_pin)

    assigns =
      assigns
      |> assign(:virtual_pin, virtual_pin)
      |> assign(:pressed, pressed)
      |> assign(:tested, tested)

    ~H"""
    <div class={[
      "w-12 h-10 rounded-lg flex flex-col items-center justify-center",
      "border-2 transition-all duration-150 ease-out",
      button_class(@pressed, @tested)
    ]}>
      <span :if={@pressed} class="text-lg">
        <.icon name="hero-hand-raised" class="w-5 h-5" />
      </span>
      <span :if={@tested and not @pressed}>
        <.icon name="hero-check" class="w-5 h-5" />
      </span>
      <span class="text-[9px] font-mono opacity-60">{@virtual_pin}</span>
    </div>
    """
  end

  defp button_class(true, true) do
    # Tested and currently pressed
    "bg-success text-success-content border-success ring-4 ring-success/30 scale-105"
  end

  defp button_class(true, false) do
    # Currently pressed (first time)
    "bg-primary text-primary-content border-primary ring-4 ring-primary/30 scale-105"
  end

  defp button_class(false, true) do
    # Tested but not currently pressed
    "bg-success/20 border-success text-success"
  end

  defp button_class(false, false) do
    # Never pressed
    "bg-base-300 border-base-300 text-base-content/30"
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-8 text-center">
      <.icon name="hero-exclamation-triangle" class="w-10 h-10 mx-auto text-warning" />
      <p class="mt-2 text-sm text-base-content/70">Matrix not configured</p>
      <p class="text-xs text-base-content/50">Add row and column pins to use this feature</p>
    </div>
    """
  end

  defp legend(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-4 mt-4 text-xs text-base-content/70">
      <div class="flex items-center gap-2">
        <div class="w-4 h-4 rounded bg-base-300 border border-base-300"></div>
        <span>Never pressed</span>
      </div>
      <div class="flex items-center gap-2">
        <div class="w-4 h-4 rounded bg-primary border border-primary"></div>
        <span>Currently pressed</span>
      </div>
      <div class="flex items-center gap-2">
        <div class="w-4 h-4 rounded bg-success/20 border border-success"></div>
        <span>Tested</span>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true

  defp action_buttons(assigns) do
    ~H"""
    <div class="flex justify-between gap-4 pt-4 mt-4 border-t border-base-300">
      <button
        phx-click="reset"
        phx-target={@myself}
        class="btn btn-ghost btn-sm"
      >
        <.icon name="hero-arrow-path" class="w-4 h-4" /> Reset
      </button>
      <button
        phx-click="close"
        phx-target={@myself}
        class="btn btn-primary btn-sm"
      >
        Close
      </button>
    </div>
    """
  end
end
