defmodule ICEDemo.Stream.Pi do
  @moduledoc false

  require Logger

  @script :code.priv_dir(:ice_demo) |> Path.join("stream_pi.sh")

  ## API

  @doc """
  Starts RTP stream of given file using Raspberry PI camera

  Following options are required:
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
    Logger.metadata tag: "Stream.Pi"
    Process.flag :trap_exit, true
    proc = start_stream(opts)
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

  defp start_stream(opts) do
    Porcelain.spawn(@script,
      [opts[:ip], opts[:port], opts[:control_port]],
      out: {:send, self()}, err: {:send, self()})
  end
end
