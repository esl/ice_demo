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
                   video_file: String.t,
                   streamer: module,
                   streamer_pid: nil | pid,
                   streamer_ref: nil | reference}

  @reconnect_interval 10_000

  def start_static do
    start jid: "movie@erlang-solutions.com",
      password: "1234",
      host: "xmpp.erlang-solutions.com",
      turn_addr: "217.182.204.9:12100",
      turn_username: "streamer",
      turn_secret: "Zd5Pb2O2",
      video_file: "sintel.h264",
      streamer: ICEDemo.Stream.Static
  end

  def start_pi do
    start jid: "camera@erlang-solutions.com",
      password: "1234",
      host: "xmpp.erlang-solutions.com",
      turn_addr: "217.182.204.9:12100",
      turn_username: "streamer",
      turn_secret: "Zd5Pb2O2",
      video_file: "sintel.h264",
      streamer: ICEDemo.Stream.Pi
  end

  @doc """
  Starts XMPP client process which triggers RTP stream

  Required options are:
  * `:jid`
  * `:password`
  * `:host` - hostname of a XMPP server
  * `:turn_addr` - address of a TURN server (ip:port format)
  * `:turn_username` - username for a TURN server
  * `:turn_secret` - secret for a TURN server:
  * `:video_file` - path to a video file which will be streamed
  * `:streamer` - streamer module (ICEDemo.Stream.Pi or ICEDemo.Stream.Static)
  """
  def start(opts) do
    Supervisor.start_child(ICEDemo.XMPP.Supervisor, [opts])
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## GenServer callbacks

  def init(opts) do
    start_opts = [jid: opts[:jid], password: opts[:password], host: opts[:host]]
    conn = init_conn(start_opts)
    schedule_reconnect(start_opts)

    Logger.metadata tag: opts[:jid]

    turn_addr = parse_turn_address(opts[:turn_addr])

    state = %{conn: conn,
              jid: opts[:jid],
              turn_addr: turn_addr,
              turn_username: opts[:turn_username],
              turn_secret: opts[:turn_secret],
              video_file: opts[:video_file],
              streamer_pid: nil,
              streamer_ref: nil,
              streamer: opts[:streamer]}
    {:ok, state}
  end

  def handle_info({:stanza, stanza}, state) do
    new_state = handle_stanza(state, stanza)
    {:noreply, new_state}
  end
  def handle_info({:DOWN, ref, _, _, _}, %{streamer_ref: ref} = state) do
    new_state = %{state | streamer_pid: nil, streamer_ref: nil}
    {:noreply, new_state}
  end
  def handle_info({:reconnect, start_opts}, state) do
    Conn.close(state.conn)
    new_conn = init_conn(start_opts)
    schedule_reconnect(start_opts)
    {:noreply, %{state | conn: new_conn}}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  ## Internals

  defp init_conn(start_opts) do
    {:ok, conn} = Conn.start_link(start_opts)
    :ok = Conn.send(conn, Stanza.presence())
    :ok = Conn.send(conn, Stanza.get_roster())
    conn
  end

  defp schedule_reconnect(start_opts) do
    Process.send_after self(), {:reconnect, start_opts}, @reconnect_interval
  end

  defp handle_stanza(state, stanza) do
    with {:ok, ip, port, control_port} <- find_stream_target(state, stanza) do
      send_public_ip(state, stanza.from.full)
      start_video_stream(state, ip, port, control_port)
    else
      _ -> maybe_stop_stream(state, stanza)
    end
  end

  defp find_stream_target(state, stanza) do
    with {:ok, body} <- get_body(stanza.xml),
         [addr, control_addr]   <- String.split(body, ";"),
         [ip, port]  <- String.split(addr, ":"),
         [_, control_port]  <- String.split(control_addr, ":") do
      {:ok, ip, port, control_port}
    end
  end

  defp maybe_stop_stream(state, stanza) do
    with {:ok, body} <- get_body(stanza.xml),
         true        <- body =~ ~r"stop.*" do
      ICEDemo.Stream.Static.stop(state.streamer_pid)
      %{state | streamer_pid: nil, streamer_ref: nil}
    else
      _ -> state
    end
  end

  defp get_body(xmlel(children: children)) do
    case find_body(children) do
      {:ok, el} ->
        get_data(el)
      :error ->
        :error
    end
  end
  defp get_body(_), do: :error

  defp find_body([]), do: :error
  defp find_body([xmlel(name: "body") = el | _]), do: {:ok, el}
  defp find_body([_ | tail]), do: find_body(tail)

  defp get_data(xmlel(children: children)) do
    data =
      Enum.reduce(children, "",
        fn xmlcdata(content: content), acc -> acc <> content
           _, acc -> acc
        end)
    {:ok, data}
  end
  defp get_data(_), do: :error

  defp send_public_ip(state, to) do
    address = get_public_ip(state)
    message = Stanza.message(to, "normal", address)
    Conn.send(state.conn, message)
  end

  defp get_public_ip(state) do
    {:ok, turn} = Jerboa.Client.start server: state[:turn_addr],
      username: state[:turn_username], secret: state[:turn_secret]
    {:ok, {ip, _}} = Jerboa.Client.bind(turn)
    :ok = Jerboa.Client.stop(turn)
    ip |> :inet.ntoa() |> to_string()
  end

  defp start_video_stream(state, ip, port, control_port) do
    if state.streamer_pid do
      ICEDemo.Stream.Static.stop(state.streamer_pid)
    end
    {:ok, pid} = state.streamer.start file: state[:video_file],
      ip: ip, port: port, control_port: control_port
    ref = Process.monitor(pid)
    %{state | streamer_pid: pid, streamer_ref: ref}
  end

  defp parse_turn_address(addr) do
    [ip_str, port_str] = String.split(addr, ":")
    {port, _} = Integer.parse(port_str)
    {:ok, ip} = ip_str |> to_charlist() |> :inet.parse_address()
    {ip, port}
  end
end
