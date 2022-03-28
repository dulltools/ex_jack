defmodule ExJack.Server do
  use GenServer

  defstruct handler: nil, shutdown_handler: nil, current_frame: 0, callback: &ExJack.Server.noop/1

  @type t :: %__MODULE__{
          handler: any(),
          shutdown_handler: any(),
          current_frame: pos_integer(),
          callback: callback_t
        }

  @type frames_t :: list(float())
  @type callback_t :: (Range.t() -> frames_t)
  @type options_t :: %{name: String.t()}

  def noop(_) do
    []
  end

  @spec start_link(options_t) :: GenServer.server()
  def start_link(%{name: _} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec set_callback(callback_t) :: GenServer.server()
  def set_callback(callback) do
    GenServer.cast(__MODULE__, {:set_callback, callback})
  end

  @spec send_frames(callback_t) :: GenServer.server()
  def send_frames(frames) do
    unless Enum.empty?(frames) do
      GenServer.cast(__MODULE__, {:send_frames, frames})
    end
  end

  @impl true
  @spec init(options_t) :: {:ok, map()}
  def init(opts) do
    {:ok, handler, shutdown_handler, _opts} = ExJack.Native.start(opts)

    {:ok, %__MODULE__{handler: handler, shutdown_handler: shutdown_handler, current_frame: 0}}
  end

  @impl true
  @spec handle_cast({:set_callback, callback_t}, t()) :: {:noreply, t()}
  def handle_cast({:set_callback, callback}, state) do
    {:noreply, %{state | callback: callback}}
  end

  @spec handle_cast({:send_frames, frames_t}, t()) :: {:noreply, t()}
  def handle_cast({:send_frames, frames}, %{handler: handler} = state) do
    ExJack.Native.send_frames(handler, frames)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:request, pos_integer()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:request, requested_frames},
        %{current_frame: current_frame, callback: callback} = state
      ) do
    end_frames = current_frame + requested_frames - 1
    send_frames(callback.(current_frame..end_frames))

    {:noreply, %{state | current_frame: end_frames + 1}}
  end

  @impl true
  def terminate(_reason, %{shutdown_handler: shutdown_handler}) do
    ExJack.Native.stop(shutdown_handler)
    :ok
  end
end
