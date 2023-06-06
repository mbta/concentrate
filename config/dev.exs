import Config

for config <- "*.local.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end
