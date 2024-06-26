defmodule Concentrate.GTFS.Unzip do
  @moduledoc """
  Unzips the GTFS file into constituent files.
  """
  @behaviour Concentrate.Parser
  # zip file_list takes charlists
  @file_list [~c"agency.txt", ~c"routes.txt", ~c"trips.txt", ~c"stop_times.txt", ~c"stops.txt"]

  def parse(binary, _opts) do
    {:ok, files} = :zip.unzip(binary, [:memory, file_list: @file_list])

    for {filename_list, body} <- files do
      body = strip_bom(body)
      {List.to_string(filename_list), body}
    end
  end

  @doc "Strip the (optional) Unicode Byte-Order-Mark from the given binary."
  def strip_bom(binary) do
    case :unicode.bom_to_encoding(binary) do
      {_, 0} ->
        binary

      {:utf8, length} ->
        binary_part(binary, length, byte_size(binary) - length)
    end
  end
end
