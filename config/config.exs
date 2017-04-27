use Mix.Config

config :logger, :console,
  metadata: [:tag, :jerboa_client, :jerboa_server],
  level: :debug
