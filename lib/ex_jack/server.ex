defmodule ExJack.Server do
  use GenServer

  require Logger

  defstruct frame_channel: nil, current_frame: 0, callback: &ExJack.Server.noop/1

  def noop(_) do 
  end

  def start_link(%{callback: _, name: _} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(%{callback: callback, name: name} = _opts) do
    {:ok, frame_channel, _buffer_size} = ExJack.Native.start(%{name: name})

    {:ok, %__MODULE__{frame_channel: frame_channel, current_frame: 0, callback: callback}}
  end

  def handle_cast({:send_frames, frames}, %{frame_channel: frame_channel} = state) do
    ExJack.Native.send_frames(frame_channel, frames)

    {:noreply, state}
  end

  def handle_info({:request, requested_frames}, %{current_frame: current_frame, callback: callback} = state) do
    end_frames = current_frame + requested_frames - 1
    send_frames(callback.(current_frame..end_frames))

    {:noreply, Map.put(state, :current_frame, end_frames + 1)}
  end

  def send_frames(frames) do
    GenServer.cast(__MODULE__, {:send_frames, frames})
  end

  def terminate(_, state) do
    #ExJack.stop(state.shutdown)
    :ok
  end
end
