defmodule Concentrate.Sink.FilesystemTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Sink.Filesystem

  describe "start_link/2" do
    setup :temp_dir

    test "writes to a file", %{directory: directory} do
      {:ok, pid} = start_link([directory: directory], {"a", "a body"})
      await_down(pid)

      assert File.read!(Path.join(directory, "a")) == "a body"
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

  def await_down(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    end
  end
end
