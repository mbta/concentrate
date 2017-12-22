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

  @type data :: term
  @type state :: term

  @callback init() :: {:serial | :parallel, state}
  @callback filter(data, state) :: {:cont, data, state} | {:skip, state}

  @doc """
  Given a list of Concentrate.Filter modules, applies them to the list of data.
  """
  @spec run([data], [module]) :: [data]
  def run(data_list, filter_list) do
    runner = build_runner(filter_list)
    runner.(data_list)
  end

  @spec build_runner([module]) :: ([data] -> [data])
  defp build_runner(filter_list) do
    do_build_runner(Enum.reverse(filter_list), &Enum.into(&1, []))
  end

  defp do_build_runner(filter_list, runner)

  defp do_build_runner([], runner) do
    runner
  end

  defp do_build_runner([filter | rest], runner) do
    {filter_type, state} = filter.init()
    filter_fun = &filter.filter/2
    new_runner = do_build_runner_of_type(filter_type, state, filter_fun, runner)
    do_build_runner(rest, new_runner)
  end

  defp do_build_runner_of_type(:parallel, state, fun, runner) do
    fn stream ->
      new_stream =
        stream
        |> Task.async_stream(&fun.(&1, state))
        |> Stream.flat_map(&parallel_runner_flat_map/1)

      runner.(new_stream)
    end
  end

  defp do_build_runner_of_type(:serial, state, fun, runner) do
    fn stream ->
      new_stream = Stream.transform(stream, state, &serial_runner_transform(fun, &1, &2))

      runner.(new_stream)
    end
  end

  defp parallel_runner_flat_map({:ok, result}) do
    case result do
      {:cont, value, _state} -> [value]
      {:skip, _state} -> []
    end
  end

  defp serial_runner_transform(fun, data, acc) do
    case fun.(data, acc) do
      {:cont, value, acc} -> {[value], acc}
      {:skip, acc} -> {[], acc}
    end
  end
end
