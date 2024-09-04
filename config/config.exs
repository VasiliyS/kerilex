import Config

config :logger,
  level: :debug,
  backends: [:console]

import_config "#{config_env()}.exs"
