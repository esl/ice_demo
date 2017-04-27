defmodule ICEDemo.XMPP.Supervisor do
  @moduledoc false

  def start_link do
    import Supervisor.Spec, warn: false

    children = [
      worker(ICEDemo.XMPP.Client, [])
    ]

    opts = [strategy: :simple_one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
