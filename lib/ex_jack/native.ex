defmodule ExJack.Native do
  use Rustler, otp_app: :ex_jack, crate: "exjack"

  def start(_opts), do: error()
  def stop(_resource), do: error()
  def send_frames(_resource, _frames), do: error()

  defp error, do: :erlang.nif_error(:ex_jack_not_loaded)
end
