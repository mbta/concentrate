defmodule Concentrate.Sink.ConsumerSupervisor do
  @moduledoc """
  ConsumerSupervisor is responsible for managing the pool of sink
  processes.
  """
  @supervisor_opts ~w(subscribe_to)a

  def start_link({sink_child, opts}) do
    supervisor_opts =
      opts
      |> Keyword.take(@supervisor_opts)
      |> Keyword.put(:strategy, :one_for_one)

    opts =
      opts
      |> Keyword.drop(@supervisor_opts)
      |> Keyword.put(:restart, :temporary)

    children = [
      {sink_child, opts}
    ]

    Supervisor.start_link(children, supervisor_opts)
  end

  def child_spec({sink_child, opts}) do
    %{
      id: {__MODULE__, sink_child},
      type: :supervisor,
      start: {__MODULE__, :start_link, [{sink_child, opts}]}
    }
  end
end
