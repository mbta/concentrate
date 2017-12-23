defmodule Concentrate.Filter.GTFS.UnzipTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.GTFS.Unzip

  describe "parse/1" do
    test "returns the trips.txt body" do
      body = "body"
      # all the zip module arguments are charlists, hence the single quotes
      {:ok, {_, zip_file}} = :zip.create('gtfs.zip', [{'trips.txt', body}], [:memory])
      assert is_binary(zip_file)
      assert parse(zip_file) == [{"trips.txt", body}]
    end
  end
end
