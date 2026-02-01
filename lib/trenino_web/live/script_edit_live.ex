defmodule TreninoWeb.ScriptEditLive do
  @moduledoc """
  LiveView for editing Lua scripts attached to train configurations.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents

  alias Trenino.Train, as: TrainContext

  @impl true
  def mount(%{"train_id" => train_id_str, "script_id" => script_id_str}, _session, socket) do
    train_id = String.to_integer(train_id_str)
    script_id = String.to_integer(script_id_str)

    with {:ok, train} <- TrainContext.get_train(train_id),
         {:ok, script} <- TrainContext.get_script(script_id) do
      {:ok,
       socket
       |> assign(:train, train)
       |> assign(:script, script)
       |> assign(:new_mode, false)
       |> assign(:page_title, "Edit Script - #{script.name}")}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Not found")
         |> redirect(to: ~p"/trains")}
    end
  end

  @impl true
  def mount(%{"train_id" => train_id_str}, _session, socket) do
    train_id = String.to_integer(train_id_str)

    case TrainContext.get_train(train_id) do
      {:ok, train} ->
        {:ok,
         socket
         |> assign(:train, train)
         |> assign(:script, nil)
         |> assign(:new_mode, true)
         |> assign(:page_title, "New Script")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Train not found")
         |> redirect(to: ~p"/trains")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Trains", path: ~p"/trains"},
      %{label: @train.name, path: ~p"/trains/#{@train.id}"},
      %{label: if(@new_mode, do: "New Script", else: @script.name)}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-4xl mx-auto">
        <p class="text-base-content/60">Script editor - coming soon</p>
      </div>
    </main>
    """
  end
end
