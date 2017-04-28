defmodule ICEDemo.Stream.Static do
  @moduledoc false

  require Logger

  @wrapper :code.priv_dir(:ice_demo) |> Path.join("wrapper.sh")

  ## API

  @doc """
  Starts RTP stream of given file using FFmpeg

  Following options are required:
  * `:file` - path to a h264 encoded file to stream
  * `:ip` - target IP address
  * `:port` - target port number
  * `:control_port` - target RTCP port
  """
  def start(opts) do
    Supervisor.start_child(ICEDemo.Stream.Supervisor, [__MODULE__, opts])
  end

  def stop(pid) do
    Supervisor.terminate_child(ICEDemo.Stream.Supervisor, pid)
  end

  ## GenServer callbacks

  def init(opts) do
    Logger.metadata tag: "Stream.Static"
    Process.flag :trap_exit, true
    proc = start_ffmpeg(opts)
    Logger.debug "Starting with opts: #{inspect opts}"
    {:ok, proc}
  end

  def handle_info({pid, :data, :out, data}, %{pid: pid} = state) do
    Logger.debug data
    {:noreply, state}
  end
  def handle_info({pid, :data, :err, data}, %{pid: pid} = state) do
    Logger.warn data
    {:noreply, state}
  end
  def handle_info({pid, :result, result}, %{pid: pid} = state) do
    log =
      if result do
        "Finished with result: #{inspect result.status}"
      else
        "Finished"
      end
    Logger.debug log
    {:stop, :normal, state}
  end

  def terminate(_, proc) do
    Porcelain.Process.stop proc
  end

  ## Internals

  defp start_ffmpeg(opts) do
    Porcelain.spawn(@wrapper,
      ["ffmpeg", "-re",  "-i", opts[:file],
       "-map", "0:0", "-vcodec", "h264",
       "-f",  "rtp",
       "rtp://#{opts[:ip]}:#{opts[:port]}?pkt_size=1300&rtcpport=#{opts[:control_port]}"],
      out: {:send, self()}, err: {:send, self()})
  end
end
