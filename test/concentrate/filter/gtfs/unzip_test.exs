defmodule Concentrate.Filter.GTFS.UnzipTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.GTFS.Unzip

  describe "parse/1" do
    test "returns the relevants bodies" do
      bodies =
        for name <- ~w(trips.txt stop_times.txt other) do
          {String.to_charlist(name), "#{name} body"}
        end

      # all the zip module arguments are charlists, hence the single quotes
      {:ok, {_, zip_file}} = :zip.create('gtfs.zip', bodies, [:memory])
      assert is_binary(zip_file)
      parsed = parse(zip_file)
      assert find_body(parsed, "trips.txt") == "trips.txt body"
      assert find_body(parsed, "stop_times.txt") == "stop_times.txt body"
      assert find_body(parsed, "other") == nil
    end
  end

  defp find_body(files, file_name) do
    Enum.find_value(files, fn
      {^file_name, value} -> value
      _ -> nil
    end)
  end
end
