defmodule ICEDemo do
  @moduledoc """
  Functions for starting the ICE demo
  """

  @base_schema %{jid: [required: true, default: "movie@erlang-solutions.com"],
                 password: [required: true, default: "1234"],
                 host: [required: true, default: "xmpp.erlang-solutions.com"],
                 turn_addr: [required: true],
                 turn_username: [required: true],
                 turn_secret: [required: true],
                 video_file: [required: true]}

  def start_movie(opts) do
    schema =
      @base_schema
      |> put_in([:jid, :default], "movie@erlang-solutions.com")
    start(opts, schema, ICEDemo.Stream.Static)
  end

  def start_camera(opts) do
    schema =
      @base_schema
      |> put_in([:jid, :default], "camera@erlang-solutions.com")
      |> update_in([:video_file, :required], fn _ -> false end)
    start(opts, schema, ICEDemo.Stream.P)
  end

  defp start(opts, schema, streamer) do
    case Optium.parse(opts, schema) do
      {:ok, opts} ->
        ICEDemo.XMPP.Client.start(opts ++ [streamer: streamer])
      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end
end
