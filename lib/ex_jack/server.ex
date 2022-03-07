defmodule ExJack.Server do
  use GenServer

  require Logger

  defstruct handler: nil, shutdown_handler: nil, current_frame: 0, callback: &ExJack.Server.noop/1

  def noop(_) do
    []
  end

  def start_link(%{name: _} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, handler, shutdown_handler, _opts} = ExJack.Native.start(opts)

    {:ok, %__MODULE__{handler: handler, shutdown_handler: shutdown_handler, current_frame: 0}}
  end

  def handle_cast({:set_callback, callback}, state) do
    {:noreply, %{state | callback: callback}}
  end

  def handle_cast({:send_frames, frames}, %{handler: handler} = state) do
    ExJack.Native.send_frames(handler, frames)

    {:noreply, state}
  end

  def handle_info(
        {:request, requested_frames},
        %{current_frame: current_frame, callback: callback} = state
      ) do
    end_frames = current_frame + requested_frames - 1
    send_frames(callback.(current_frame..end_frames))

    {:noreply, %{state | current_frame: end_frames + 1}}
  end

  def terminate(_reason, %{shutdown_handler: shutdown_handler}) do
    ExJack.Native.stop(shutdown_handler)
    :ok
  end

  def set_callback(callback) do
    GenServer.cast(__MODULE__, {:set_callback, callback})
  end

  def send_frames(frames) do
    unless Enum.empty?(frames) do
      GenServer.cast(__MODULE__, {:send_frames, frames})
    end
  end
end
