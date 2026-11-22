defmodule Trenino.Simulator.Backend.SimRail do
  @moduledoc """
  SimRail backend: talks to the TreninoBridge MelonLoader mod
  (`integrations/simrail/README.md`) over HTTP and its WebSocket stream.

  The handle is a `%SimRail{}`. `connect/1` only builds it; the WebSocket
  (`SimRail.Stream`) starts on the first `watch/3` and is stopped by
  `disconnect/1`, one stream per handle.

  Paths are `Group.field` (`"Physics_Input_EN57.maincontroller_a"`); values
  are floats (booleans are 0/1).

  Errors: `{:error, {:invalid_key, body}}` on 401 (as the TSW client),
  `{:error, :not_in_train}` on 409, `{:error, :invalid_path}` on 404 or for a
  path the bridge does not report, `{:error, {:http_error, status, body}}`
  otherwise and `{:error, {:request_failed, reason}}` when the bridge cannot
  be reached.
  """

  @behaviour Trenino.Simulator.Backend

  alias Trenino.Simulator.Backend.SimRail.{Schema, Stream}

  @default_max_hz 30
  @connect_timeout_ms 1_000
  @check_timeout_ms 2_000

  # Keep the bridge token (also in the request headers) out of crash reports.
  @derive {Inspect, except: [:api_key, :req]}
  @enforce_keys [:url, :req, :ref]
  defstruct [:url, :api_key, :req, :ref, max_hz: @default_max_hz, stream_opts: []]

  @type t :: %__MODULE__{
          url: String.t(),
          api_key: String.t() | nil,
          req: Req.Request.t(),
          ref: reference(),
          max_hz: pos_integer(),
          stream_opts: keyword()
        }

  @impl true
  def id, do: :simrail

  @impl true
  def capabilities, do: [:push_values, :control_catalog, :vehicle_events]

  @doc """
  Build a handle. `config` takes `:url` (e.g. `"http://127.0.0.1:31275"`) and
  an optional `:api_key` (the bridge token, needed only from another
  computer), plus optional `:max_hz` (stream rate, 1-120) and
  `:stream_opts` (`Stream` options such as `:backoff_ms`).
  """
  @impl true
  def connect(%{url: url} = config) when is_binary(url) and url != "" do
    api_key = blank_to_nil(Map.get(config, :api_key))
    url = String.trim_trailing(url, "/")

    {:ok,
     %__MODULE__{
       url: url,
       api_key: api_key,
       req: new_req(url, api_key),
       ref: make_ref(),
       max_hz: Map.get(config, :max_hz, @default_max_hz),
       stream_opts: Map.get(config, :stream_opts, [])
     }}
  end

  def connect(_config), do: {:error, :needs_config}

  @impl true
  def check(%__MODULE__{req: req}) do
    req
    |> Req.get(url: "/api/v1/status", receive_timeout: @check_timeout_ms)
    |> handle_response()
  end

  @impl true
  def disconnect(%__MODULE__{ref: ref}), do: Stream.stop(ref)

  @impl true
  def get(%__MODULE__{} = handle, path) when is_binary(path) do
    with {:ok, values} <- read(handle, [path]) do
      case Map.fetch(values, path) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, :invalid_path}
      end
    end
  end

  @impl true
  def read(%__MODULE__{}, []), do: {:ok, %{}}

  def read(%__MODULE__{req: req}, paths) when is_list(paths) do
    with {:ok, values} when is_map(values) <-
           req
           |> Req.get(url: "/api/v1/values", params: [paths: Enum.join(paths, ",")])
           |> handle_response() do
      {:ok, normalize_values(values)}
    end
  end

  @impl true
  def set(%__MODULE__{req: req}, path, value) when is_binary(path) do
    with {:ok, number} <- to_number(value),
         {:ok, _result} <-
           req
           |> Req.put(url: "/api/v1/values/" <> encode_segment(path), json: %{value: number})
           |> handle_response() do
      :ok
    end
  end

  @impl true
  def vehicle_id(%__MODULE__{} = handle) do
    with {:ok, schema} <- vehicle(handle) do
      case Schema.vehicle_name(schema) do
        nil -> {:error, {:unexpected_response, schema}}
        name -> {:ok, name}
      end
    end
  end

  @impl true
  def controls(%__MODULE__{} = handle) do
    with {:ok, schema} <- vehicle(handle), do: {:ok, Schema.controls(schema)}
  end

  @impl true
  def watch(%__MODULE__{} = handle, paths, pid) when is_list(paths) and is_pid(pid) do
    Stream.watch(handle, paths, pid)
  end

  @doc """
  The handle's stream process (started by the first `watch/3`), or nil.

  The stream keeps its watchers in memory only: after it exits (crash or
  `disconnect/1`) nothing is pushed any more. Watchers monitor this pid and
  call `watch/3` again when it goes down.
  """
  @impl true
  @spec watch_process(t()) :: pid() | nil
  def watch_process(%__MODULE__{ref: ref}), do: Stream.whereis(ref)

  @doc "The raw vehicle schema (`GET /api/v1/vehicle`)."
  @spec vehicle(t()) :: {:ok, map()} | {:error, term()}
  def vehicle(%__MODULE__{req: req}) do
    req |> Req.get(url: "/api/v1/vehicle") |> handle_response()
  end

  @doc false
  @spec normalize_values(map()) :: %{String.t() => float()}
  def normalize_values(values) when is_map(values) do
    for {path, value} <- values, number = Schema.to_float(value), into: %{}, do: {path, number}
  end

  defp new_req(url, api_key) do
    Req.new(
      base_url: url,
      headers: auth_headers(api_key),
      connect_options: [timeout: @connect_timeout_ms],
      receive_timeout: 5_000,
      retry: false
    )
  end

  @doc false
  @spec auth_headers(String.t() | nil) :: [{String.t(), String.t()}]
  def auth_headers(nil), do: []
  def auth_headers(token), do: [{"authorization", "Bearer " <> token}]

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}), do: {:ok, body}

  defp handle_response({:ok, %Req.Response{status: 401, body: body}}),
    do: {:error, {:invalid_key, body}}

  defp handle_response({:ok, %Req.Response{status: 404}}), do: {:error, :invalid_path}
  defp handle_response({:ok, %Req.Response{status: 409}}), do: {:error, :not_in_train}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, {:http_error, status, body}}

  defp handle_response({:error, reason}), do: {:error, {:request_failed, reason}}

  defp to_number(true), do: {:ok, 1}
  defp to_number(false), do: {:ok, 0}
  defp to_number(value) when is_number(value), do: {:ok, value}
  defp to_number(value), do: {:error, {:invalid_value, value}}

  defp encode_segment(path), do: URI.encode(path, &URI.char_unreserved?/1)

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value) when is_binary(value), do: value
end
