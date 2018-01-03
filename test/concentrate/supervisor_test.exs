defmodule Concentrate.SupervisorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Supervisor

  describe "start_link/0" do
    test "can start the application" do
      assert {:ok, _pid} = start_link()
    end
  end

  describe "children/1" do
    test "builds the right number of children" do
      # currently, the right number is (number of sources + number of files + 5)
      config = [
        sources: [
          gtfs_realtime: [
            name: "url",
            name2: "url2"
          ]
        ],
        encoders: [files: [{"filename", :module}, {"other_file", :other_mod}]],
        sinks: [filesystem: [directory: "/tmp"]]
      ]

      actual = children(config)

      assert length(actual) == 9
    end
  end
end
