defmodule Concentrate.Filter.GTFS.Unzip do
  @moduledoc """
  Unzips the GTFS file into constituent files.
  """
  @file_list ['trips.txt', 'stop_times.txt']

  def parse(binary) do
    {:ok, files} = :zip.unzip(binary, [:memory, file_list: @file_list])

    for {filename_list, body} <- files do
      {List.to_string(filename_list), body}
    end
  end
end
