defmodule Concentrate.Producer.FileTapTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Producer.FileTap

  describe "start_link/2" do
    test "creates a server" do
      assert {:ok, _} = start_supervised(Concentrate.Producer.FileTap)
    end
  end

  describe "log_body/3" do
    test "doesn't crash when the server isn't running" do
      assert :ok = log_body("", "", DateTime.utc_now())
    end
  end

  describe "handle_demand/2" do
    setup :state

    test "adds the demand to the server", %{state: state} do
      {:noreply, [], state} = handle_demand(5, state)
      assert %{demand: 5} = state
      {:noreply, [], state} = handle_demand(10, state)
      assert %{demand: 15} = state
    end

    test "if there's enough in the body, sends it", %{state: state} do
      {:noreply, [], state} =
        handle_cast({:log_body, "body", "url/path", DateTime.utc_now()}, state)

      {:noreply, [{filename, body}], state} = handle_demand(1, state)
      assert %{demand: 0} = state
      assert body == "body"
      assert filename =~ "_url_path"
    end

    test "if there isn't enough demand for all of the body, it sends some of it", %{state: state} do
      {:noreply, [], state} =
        handle_cast({:log_body, "body", "url/path", DateTime.utc_now()}, state)

      {:noreply, [], state} =
        handle_cast({:log_body, "other body", "other url", DateTime.utc_now()}, state)

      assert {:noreply, [{_, _}], state} = handle_demand(1, state)
      assert {:noreply, [{_, _}], state} = handle_demand(1, state)
      assert %{demand: 0} = state
    end
  end

  describe "handle_cast(:log_body)" do
    setup :state

    test "sends events immediately if there's available demand", %{state: state} do
      {:noreply, [], state} = handle_demand(1, state)

      assert {:noreply, [{_, _}], state} =
               handle_cast({:log_body, "body", "url", DateTime.utc_now()}, state)

      assert %{demand: 0} = state
    end

    test "if the tap isn't enabled, sending a body does nothing" do
      {_, state} = init([])
      {:noreply, [], state} = handle_demand(1, state)

      assert {:noreply, [], ^state} =
               handle_cast({:log_body, "body", "url", DateTime.utc_now()}, state)
    end
  end

  defp state(_) do
    {:producer, state} = init(enabled?: true)
    {:ok, state: state}
  end
end
