import Config
config :ex_jack, ExJack.Native, mode: :debug
config :rustler_precompiled, :force_build, ex_jack: true
