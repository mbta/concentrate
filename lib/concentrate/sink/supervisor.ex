defmodule Concentrate.Sink.Supervisor do
  @moduledoc """
  Supervisor is responsible for managing the pool of sink
  processes.
  """
  def start_link(config, sources) do
    opts = [subscribe_to: sources]

    children =
      for {sink_type, sink_config} <- config do
        child_for_sink(sink_type, opts ++ sink_config)
      end

    Supervisor.start_link(children, strategy: :rest_for_one)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts[:config], opts[:sources]]},
      type: :supervisor
    }
  end

  defp child_for_sink(sink_type, sink_config) when sink_type in [:filesystem, :s3] do
    child_module = sink_child_module(sink_type)

    {Concentrate.Sink.ConsumerSupervisor, {child_module, sink_config}}
  end

  defp child_for_sink(:mqtt, sink_config) do
    {Concentrate.Sink.Mqtt, sink_config}
  end

  defp sink_child_module(:filesystem), do: Concentrate.Sink.Filesystem
  defp sink_child_module(:s3), do: Concentrate.Sink.S3
end
