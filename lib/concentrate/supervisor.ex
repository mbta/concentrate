defmodule Concentrate.Supervisor do
  @moduledoc """
  Supervisor for Concentrate.

  Children:
  * one for the alert data
  * one for GTFS data
  * one for the pipeline
  """
  def start_link do
    config = Application.get_all_env(:concentrate)

    Supervisor.start_link(children(config), strategy: :rest_for_one)
  end

  def children(config) do
    pool = pool()
    alerts = alerts(config[:alerts])
    signs_stops_config = signs_stops_config(config[:signs_stops_config])
    gtfs = gtfs(config[:gtfs])
    pipeline = pipeline(config)
    health = health()
    Enum.concat([pool, alerts, signs_stops_config, gtfs, pipeline, health])
  end

  def pool do
    [
      :hackney_pool.child_spec(:http_producer_pool, timeout: 30_000, max_connections: 100)
    ]
  end

  def alerts(config) do
    [
      {Concentrate.Filter.Alert.Supervisor, config}
    ]
  end

  def signs_stops_config(config) do
    [
      {Concentrate.Filter.Suppress.Supervisor, config}
    ]
  end

  def gtfs(config) do
    [
      {Concentrate.GTFS.Supervisor, config}
    ]
  end

  def pipeline(config) do
    [
      %{
        id: Concentrate.Supervisor.Pipeline,
        start: {Concentrate.Supervisor.Pipeline, :start_link, [config]}
      }
    ]
  end

  def health do
    [
      {Concentrate.Health, name: Concentrate.Health}
    ]
  end
end
