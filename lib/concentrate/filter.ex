defmodule Concentrate.Filter do
  @moduledoc """
  Defines the behaviour for filtering.

  Each filter gets called for each parsed item, along with some (optional)
  state that's passed along.

  The init/0 callback indicates whether the filter can be run in parallel. If
  it can, the returned state from filter/2 is ignored: the same initial state
  is passed in for each call.

  The filter can return a new parsed item to replace the one passed in. In
  this way, you can also map over the parsed data.
  """
  require Logger

  @type data :: term
  @type state :: term

  @callback init() :: state
  @callback filter(data, state) :: {:cont, data, state} | {:skip, state}

  @doc """
  Given a list of Concentrate.Filter modules, applies them to the list of data.
  """
  @spec run([data], [module]) :: [data]
  def run(data_list, filter_list) do
    stream = Enum.reduce(filter_list, data_list, &apply_filter_to_stream/2)
    Enum.into(stream, [])
  end

  defp apply_filter_to_stream(module, stream) do
    state = module.init()

    Stream.transform(stream, state, &transform(module, &1, &2))
  end

  defp transform(module, item, state) do
    case module.filter(item, state) do
      {:cont, new_item, state} -> {[new_item], state}
      {:skip, state} -> {[], state}
    end
  end
end
