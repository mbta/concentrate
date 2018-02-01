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
  @type return :: {:cont, data, state} | {:skip, state}

  @callback init() :: state
  @callback filter(data, state) :: return
  @callback filter(data, next_data, state) :: return when next_data: data
  @callback cleanup(state) :: term
  @optional_callbacks [filter: 2, filter: 3, cleanup: 1]

  @doc """
  Given a list of Concentrate.Filter modules, applies them to the list of data.
  """
  @spec run([data], [module]) :: [data]
  def run(data_list, filter_list) do
    Enum.reduce(filter_list, data_list, &timed_apply/2)
  end

  defp timed_apply(module, enum) do
    {time, enum} = :timer.tc(&apply_filter_to_enum/2, [module, enum])

    Logger.debug(fn ->
      "#{__MODULE__} #{module} took #{time / 1000}ms"
    end)

    enum
  end

  defp apply_filter_to_enum(module, enum) do
    state = module.init()

    {enum, state} =
      if function_exported?(module, :filter, 3) do
        # filter takes the next value too
        flat_map_with_next(enum, state, module)
      else
        Enum.flat_map_reduce(enum, state, &transform(module, &1, &2))
      end

    if function_exported?(module, :cleanup, 1) do
      module.cleanup(state)
    end

    enum
  end

  defp transform(module, item, state) do
    case module.filter(item, state) do
      {:cont, item, state} -> {[item], state}
      {:skip, state} -> {[], state}
    end
  end

  defp flat_map_with_next([], state, _) do
    {[], state}
  end

  defp flat_map_with_next([_first | rest] = enum, state, module) do
    do_flat_map_with_next(enum, rest, state, module, [])
  end

  defp do_flat_map_with_next([item], _, state, module, acc) do
    case module.filter(item, nil, state) do
      {:cont, new_item, state} ->
        {Enum.reverse(acc, [new_item]), state}

      {:skip, state} ->
        {Enum.reverse(acc), state}
    end
  end

  defp do_flat_map_with_next([item | rest], [next | next_rest], state, module, acc) do
    case module.filter(item, next, state) do
      {:cont, item, state} ->
        do_flat_map_with_next(rest, next_rest, state, module, [item | acc])

      {:skip, state} ->
        do_flat_map_with_next(rest, next_rest, state, module, acc)
    end
  end
end
