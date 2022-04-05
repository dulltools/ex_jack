defmodule IoEffects do
  @moduledoc """
  Documentation for `IoEffects`.
  """

  alias IoEffects.Buffer

  def sin_freq(freq) do
    ExJack.Server.set_output_func(fn frames -> 
      frames |> sin_freq(freq)
    end)
  end

  # mono channel delay, will work for stereo+ but delay calculation will be incorrect
  def delay(ms) do
    sample_rate = ExJack.Server.get_sample_rate()
    jack_period_size = ExJack.Server.get_buffer_size()

    delay_in_frames = sample_rate * ms / 1000

    ExJack.Server.set_input_func(fn frames -> 
      :ok = Buffer.store(frames)
      buffer_size = Buffer.size()
      if buffer_size > delay_in_frames do
        frames = Buffer.flush(jack_period_size)
        ExJack.Server.send_frames(frames)
      end
    end)
  end

  def sin_freq(time, pitch) do
    radians_per_second = pitch * 2.0 * :math.pi()
    seconds_per_frame = 1.0 / 44_100.0

    Enum.map(time, fn i ->
      :math.sin(radians_per_second * i * seconds_per_frame)
    end)
  end
end
