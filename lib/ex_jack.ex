defmodule ExJack do
end

"""
defmodule ExJack do
  def load_port_driver do
    :code.priv_dir(:ex_jack)
    |> :erl_ddll.load_driver("ex_jack") 
    |> IO.inspect
    |> case do
      {:error, reason} ->
        {:error, :erl_ddll.format_error(reason)}
      ok -> ok |> IO.inspect
    end
  end

  def start() do
    case load_port_driver do
      :ok ->
        Port.open({:spawn, "ex_jack"}, [])
      error -> error
    end

  end
end
"""
