use Mix.Config

config :logger, :console,
  metadata: [:tag],
  level: :debug
