defmodule Concentrate.Filter do
  @moduledoc """
  Defines the behaviour for filtering.

  Each filter gets called for each parsed item, along with some (optional)
  state that's passed along.

  Filter modules have two callbacks:
  * `init/0` callback returns an initial term that's passed to each filter.
  * `filter/2` takes the item and the state, returning either `{:cont,
    new_item, new_state}` or `{:skip, new_state}`.
  """
  require Logger

  @type data :: term
  @type state :: term
  @type return :: {:cont, data, state} | {:skip, state}

  @callback init() :: state
  @callback filter(data, state) :: return
  @doc """
  Given a list of Concentrate.Filter modules, applies them to the list of data.
  """
  @spec run([data], [module]) :: [data]
  def run(data_list, filter_list) do
    Enum.reduce(filter_list, data_list, &apply_filter_to_enum/2)
  end

  defp apply_filter_to_enum(module, enum) do
    state = module.init()

    {enum, _state} = Enum.flat_map_reduce(enum, state, &transform(module, &1, &2))

    enum
  end

  defp transform(module, item, state) do
    case module.filter(item, state) do
      {:cont, item, state} -> {[item], state}
      {:skip, state} -> {[], state}
    end
  end
end
