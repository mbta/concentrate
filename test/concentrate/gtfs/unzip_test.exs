defmodule Concentrate.GTFS.UnzipTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GTFS.Unzip

  describe "parse/1" do
    test "returns the relevants bodies" do
      bodies =
        for name <- ~w(trips.txt stop_times.txt other) do
          {String.to_charlist(name), "#{name} body"}
        end

      # all the zip module arguments are charlists, hence the single quotes
      {:ok, {_, zip_file}} = :zip.create('gtfs.zip', bodies, [:memory])
      assert is_binary(zip_file)
      parsed = parse(zip_file, [])
      assert find_body(parsed, "trips.txt") == "trips.txt body"
      assert find_body(parsed, "stop_times.txt") == "stop_times.txt body"
      assert find_body(parsed, "other") == nil
    end
  end

  describe "strip_bom/1" do
    test "does nothing when there's no BOM" do
      assert strip_bom("1234") == "1234"
    end

    test "strips a leading BOM" do
      assert strip_bom("\uFEFF1234") == "1234"
    end
  end

  defp find_body(files, file_name) do
    Enum.find_value(files, fn
      {^file_name, value} -> value
      _ -> nil
    end)
  end
end
