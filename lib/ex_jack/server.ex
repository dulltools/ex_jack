defmodule ExJack.Server do
  use GenServer

  require Logger

  defstruct frame_channel: nil

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, frame_channel, buffer_size } = ExJack.Native.start(opts)
    {:ok, %__MODULE__{frame_channel: frame_channel}}
  end

  def handle_cast({:send_frames, frames}, %{frame_channel: frame_channel} = state) do
    ExJack.Native.send_frames(frame_channel, frames)

    {:noreply, state}
  end

  def handle_info({:request, frames}, state) do
    IO.inspect("Requesting #{frames}")
    send_frames(sin_freq(220.0, 100))

    {:noreply, state}
  end

  def send_frames(frames) do
    GenServer.cast(__MODULE__, {:send_frames, frames})
  end

  def terminate(_, state) do
    #ExJack.stop(state.shutdown)
    :ok
  end

  def sin_freq(pitch, time) do
    radians_per_second = pitch * 2.0 * :math.pi()
    seconds_per_frame = 1.0 / 44100.0

    Enum.map(0..255, fn i ->
      :math.sin(radians_per_second * i * seconds_per_frame)
    end)
  end
end
