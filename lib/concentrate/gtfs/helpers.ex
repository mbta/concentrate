defmodule Concentrate.GTFS.Helpers do
  @moduledoc "Shared helpers for `GTFS` modules."

  @doc "Turns the given binary into a Stream of lines."
  @spec io_stream(binary) :: Enumerable.t()
  def io_stream(body) when is_binary(body) do
    Stream.resource(
      fn ->
        {:ok, pid} = StringIO.open(body)
        pid
      end,
      fn pid ->
        case IO.read(pid, :line) do
          line when is_binary(line) -> {[line], pid}
          _ -> {:halt, pid}
        end
      end,
      fn pid ->
        StringIO.close(pid)
      end
    )
  end
end
