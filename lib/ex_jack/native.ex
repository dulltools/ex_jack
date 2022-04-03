defmodule ExJack.Native do
  @moduledoc """
  A Rustler NIF that interfaces with JACK. Use `ExJack.Server` instead.

  While there are only minimal number of functions compared to the JACK API, 
  the majority of interfacing is done through messages sent between the NIF 
  thread and `ExJack.Server` GenServer process.

  Typically when interfacing with ExJack, calling these methods directly isn't necessary
  and you should instead, as a client, use `ExJack.Server`.

  If you are interested in using this library, signatures and usage can be found in `ExJack.Server`.
  """

  use Rustler, otp_app: :ex_jack, crate: "exjack"

  @type options_t :: %{
          name: String.t(),
          auto_connect: boolean(),
          use_callback: boolean()
        }

  @start_defaults %{
    name: __MODULE__,
    auto_connect: true,
    use_callback: true
  }

  @spec start(options_t) :: any()
  def start(opts) do
    _start(Map.merge(@start_defaults, opts))
  end

  def _start(_opts), do: error()
  def stop(_resource), do: error()
  def send_frames(_resource, _frames), do: error()

  defp error, do: :erlang.nif_error(:ex_jack_not_loaded)
end
