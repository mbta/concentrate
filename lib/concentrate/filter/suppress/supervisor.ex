defmodule Concentrate.Filter.Suppress.Supervisor do
  @moduledoc """
  Supervisor for the extra servers needed for suppressing predictions based on signs config.

  * HTTP producer to fetch the signs config
  * Consumer / map of suppressed stops
  """
  @one_day 86_400_000

  require Logger

  def start_link(config) do
    if config[:url] do
      Supervisor.start_link(
        [
          {
            Concentrate.producer_for_url(config[:url]),
            {
              config[:url],
              parser: Concentrate.Parser.SignsConfig,
              fetch_after: 1_000,
              content_warning_timeout: @one_day,
              name: :stop_prediction_status_producer
            }
          },
          {Concentrate.Filter.Suppress.StopPredictionStatus,
           subscribe_to: [:stop_prediction_status_producer]}
        ],
        strategy: :rest_for_one
      )
    else
      :ignore
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
end
