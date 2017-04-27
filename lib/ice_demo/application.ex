defmodule ICEDemo.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(ICEDemo.Stream.Supervisor, []),
      supervisor(ICEDemo.XMPP.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: ICEDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
