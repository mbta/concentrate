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

  The cleanup/1 callback is optional: it's called after the filter is used to
  clean up the state.
  """
  require Logger

  @type data :: term
  @type state :: term

  @callback init() :: state
  @callback filter(data, state) :: {:cont, data, state} | {:skip, state}
  @callback cleanup(state) :: term
  @optional_callbacks [cleanup: 1]

  @doc """
  Given a list of Concentrate.Filter modules, applies them to the list of data.
  """
  @spec run([data], [module]) :: [data]
  def run(data_list, filter_list) do
    Enum.reduce(filter_list, data_list, &apply_filter_to_enum/2)
  end

  defp apply_filter_to_enum(module, enum) do
    state = module.init()
    {enum, state} = Enum.flat_map_reduce(enum, state, &transform(module, &1, &2))

    if function_exported?(module, :cleanup, 1) do
      module.cleanup(state)
    end

    enum
  end

  defp transform(module, item, state) do
    case module.filter(item, state) do
      {:cont, new_item, state} -> {[new_item], state}
      {:skip, state} -> {[], state}
    end
  end
end
