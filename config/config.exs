import Config

config :rustler_precompiled, :force_build, ex_jack: false
import_config "#{config_env()}.exs"
