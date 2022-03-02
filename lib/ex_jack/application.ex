defmodule ExJack.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      ExJack.Server
    ]

    opts = [strategy: :one_for_one, name: ExJack.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
