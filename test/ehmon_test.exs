defmodule EhmonTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import :ehmon
  import ExUnit.CaptureLog

  setup do
    # ensure that scheduler_wall_time is enabled
    flag = :erlang.system_flag(:scheduler_wall_time, true)

    on_exit(fn ->
      :erlang.system_flag(:scheduler_wall_time, flag)
    end)
  end

  describe "info_report/1" do
    test "logs a report" do
      log =
        capture_log(fn ->
          init()
          |> update()
          |> report()
          |> info_report()
        end)

      refute log == ""
    end
  end
end
