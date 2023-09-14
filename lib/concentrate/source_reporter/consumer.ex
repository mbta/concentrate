defmodule Concentrate.SourceReporter.Consumer do
  @moduledoc """
  Consumes output from sources and generates log output.
  """
  use GenStage
  require Logger
  alias Concentrate.FeedUpdate

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    {module, opts} = Keyword.pop(opts, :module)
    module_state = module.init()
    {:consumer, {module, module_state}, opts}
  end

  @impl GenStage
  def handle_events(events, _from, {module, module_state}) do
    module_state =
      Enum.reduce(events, module_state, fn event, module_state ->
        {output, module_state} = module.log(event, module_state)
        maybe_log(output, module, event)
        module_state
      end)

    {:noreply, [], {module, module_state}}
  end

  defp maybe_log([], _module, _event) do
    :ok
  end

  defp maybe_log([_ | _] = output, module, event) do
    Logger.info(fn ->
      report = Enum.map_join(output, " ", &log_item/1)

      "report=#{module} url=#{inspect(FeedUpdate.url(event))} #{report}"
    end)
  end

  defp log_item({key, value}) when is_binary(value) do
    "#{key}=#{inspect(value)}"
  end

  defp log_item({key, value}) do
    "#{key}=#{value}"
  end
end
