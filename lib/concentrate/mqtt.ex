defmodule Concentrate.Mqtt do
  @moduledoc """
  Helper functions shared by Concentrate.Producer.Mqtt and Concentrate.Sink.Mqtt.
  """

  @doc """
  Generate a list of `EmqttFailover.Config` structs from a given set of options.

  - splits the URL and passwords on spaces
  """
  def configs(opts) do
    opts = Concentrate.unwrap_values(opts)

    password_opts = password_opts(Keyword.get(opts, :password))

    for url <- String.split(opts[:url], " "),
        password_opt <- password_opts do
      config_opts = Keyword.take(opts, [:username]) ++ password_opt
      EmqttFailover.Config.from_url(url, config_opts)
    end
  end

  defp password_opts(passwords)

  defp password_opts(empty) when empty in [nil, ""] do
    [[]]
  end

  defp password_opts(passwords) when is_binary(passwords) do
    for password <- String.split(passwords, " "), do: [password: password]
  end
end
