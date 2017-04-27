defmodule ICEDemo.XMPP.Client do
  @moduledoc """
  XMPP client receiving IP address of a peer to start
  RTP stream
  """

  use GenServer

  alias Romeo.Stanza
  alias Romeo.Connection, as: Conn

  require Logger

  @type state :: %{conn: pid, jid: String.t}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## GenServer callbacks

  def init(opts) do
    start_opts = [jid: opts[:jid], password: opts[:password], host: opts[:host]]

    {:ok, conn} = Conn.start_link(start_opts)
    :ok = Conn.send(conn, Stanza.presence())
    :ok = Conn.send(conn, Stanza.get_roster())

    Logger.metadata tag: opts[:jid]

    state = %{conn: conn, jid: opts[:jid]}
    {:ok, state}
  end

  def handle_info({:stanza, stanza}, state) do
    ## handle stanza from Mangosta here
    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end
end
