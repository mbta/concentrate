defmodule Concentrate.HealthTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Concentrate.Health

  describe "healthy?" do
    test "crashes by default" do
      healthy?(:health_false)
      assert false
    catch
      :exit, _ ->
        true
    end

    test "true when the server is running" do
      {:ok, pid} = start_link([])
      assert healthy?(pid)
    end

    test "logs a message" do
      {:ok, pid} = start_link([])

      log =
        capture_log(fn ->
          healthy?(pid)
        end)

      assert log =~ "Health"
    end
  end
end
