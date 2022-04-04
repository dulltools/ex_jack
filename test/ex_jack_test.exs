defmodule ExJackTest do
  use ExUnit.Case, async: true
  doctest ExJack

  setup do
    server = start_supervised!({ExJack.Server, %{name: "ExJackTest"}})
    :ok
  end

  describe "Mixer" do
    test "calls tracks and mixes them together using configurable algorithm" do
      ExJack.Server.set_output_func(&a220/1)
      :timer.sleep(1000)
      ExJack.Server.set_output_func(&a440/1)
      :timer.sleep(500)
      ExJack.Server.set_output_func(&noop/1)
      :timer.sleep(500)
      ExJack.Server.set_output_func(&a220/1)
      :timer.sleep(1000)
      ExJack.Server.set_output_func(&a440/1)
      :timer.sleep(500)
      ExJack.Server.set_output_func(&noop/1)
      :timer.sleep(500)
      ExJack.Server.set_output_func(&a220/1)
    end
  end

  def sin_freq(time, pitch) do
    radians_per_second = pitch * 2.0 * :math.pi()
    seconds_per_frame = 1.0 / 44100.0

    Enum.map(time, fn i ->
      :math.sin(radians_per_second * i * seconds_per_frame)
    end)
  end

  def noop(frames) do
    frames |> Enum.map(fn _ -> 0.0 end)
  end

  def a220(time) do
    time |> sin_freq(220)
  end

  def a440(time) do
    time |> sin_freq(440)
  end
end
