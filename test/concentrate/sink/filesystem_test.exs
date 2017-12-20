defmodule Concentrate.Sink.FilesystemTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Sink.Filesystem

  describe "handle_events/1" do
    setup :temp_dir

    test "writes to each file", %{directory: directory} do
      {_, state, _} = init(directory: directory)
      _ = handle_events([{"a", "a"}, {"b", "b"}], :from, state)

      assert File.read!(Path.join(directory, "a")) == "a"
      assert File.read!(Path.join(directory, "b")) == "b"
    end
  end

  def temp_dir(_) do
    temp_dir = Path.join(System.tmp_dir!(), "tmp_#{System.unique_integer()}")

    case File.mkdir(temp_dir) do
      :ok ->
        on_exit(fn ->
          File.rm_rf!(temp_dir)
        end)

        %{directory: temp_dir}

      {:error, :eexist} ->
        temp_dir(nil)
    end
  end
end
