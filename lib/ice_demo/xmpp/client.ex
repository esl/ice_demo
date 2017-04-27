defmodule ICEDemo.XMPP.Client do
  @moduledoc """
  XMPP client receiving IP address of a peer to start
  RTP stream
  """

  use GenServer

  alias Romeo.Stanza
  alias Romeo.Connection, as: Conn

  require Record
  require Logger

  Record.defrecordp :xmlel, Record.extract(:xmlel,
    from_lib: "fast_xml/include/fxml.hrl")
  Record.defrecordp :xmlcdata, content: ""

  @type state :: %{conn: pid,
                   jid: String.t,
                   turn_addr: Jerboa.Client.address,
                   turn_username: String.t,
                   turn_secret: String.t,
                   video_file: String.t}

  def start_test do
    start_link jid: "streamer@erlang-solutions.com",
      password: "1234",
      host: "xmpp.erlang-solutions.com",
      turn_addr: "127.0.0.1:12100",
      turn_username: "streamer",
      turn_secret: "abc",
      video_file: "sintel.h264"
  end

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

    turn_addr = parse_turn_address(opts[:turn_addr])

    state = %{conn: conn,
              jid: opts[:jid],
              turn_addr: turn_addr,
              turn_username: opts[:turn_username],
              turn_secret: opts[:turn_secret],
              video_file: opts[:video_file]}
    {:ok, state}
  end

  def handle_info({:stanza, stanza}, state) do
    case find_stream_target(state, stanza) do
      {:ok, ip, port} ->
        send_public_ip(state, stanza.from.full)
        start_video_stream(state, ip, port)
      :error ->
        :ok
    end
    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  ## Internals

  defp find_stream_target(state, stanza) do
    ## TODO: get IP of stream target from stanza
    bare_jid_from = "#{stanza.from.user}@#{stanza.from.server}"
    if bare_jid_from != state.jid do
      {:ok, "127.0.0.1", "4321"}
    else
      :error
    end
  end

  defp send_public_ip(state, to) do
    ## TODO: send public IP in required format
    address = get_public_ip(state)
    message = Stanza.message(to, "", address)
    Conn.send(state.conn, message)
  end

  defp get_public_ip(state) do
    {:ok, turn} = Jerboa.Client.start server: state[:turn_addr],
      username: state[:turn_username], secret: state[:turn_secret]
    {:ok, {ip, _}} = Jerboa.Client.bind(turn)
    :ok = Jerboa.Client.stop(turn)
    ip |> :inet.ntoa() |> to_string()
  end

  defp start_video_stream(state, ip, port) do
    ICEDemo.Stream.Static.start file: state[:video_file], ip: ip, port: port
  end

  defp parse_turn_address(addr) do
    [ip_str, port_str] = String.split(addr, ":")
    {port, _} = Integer.parse(port_str)
    {:ok, ip} = ip_str |> to_charlist() |> :inet.parse_address()
    {ip, port}
  end
end
