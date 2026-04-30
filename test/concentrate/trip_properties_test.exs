defmodule Concentrate.TripPropertiesTest do
  @moduledoc false
  use ExUnit.Case
  alias Concentrate.Mergeable
  alias Concentrate.TripProperties

  describe "new_from_proto/2" do
    test "sets source trip_id" do
      proto = %{trip_id: "newfangled"}
      actual = TripProperties.new_from_proto(proto, "oldskool")

      expected = %TripProperties{
        source_trip_id: "oldskool",
        new_trip_id: "newfangled"
      }

      assert actual == expected
    end

    test "gets field values from proto" do
      proto = %{
        trip_id: "clone",
        start_date: "19991231",
        start_time: "12:34:56",
        shape_id: "wiggles",
        trip_headsign: "boo",
        trip_short_name: "SL-2000"
      }

      actual = TripProperties.new_from_proto(proto, "orig")

      expected = %TripProperties{
        source_trip_id: "orig",
        new_trip_id: "clone",
        start_date: "19991231",
        start_time: "12:34:56",
        shape_id: "wiggles",
        trip_headsign: "boo",
        trip_short_name: "SL-2000"
      }

      assert actual == expected
    end

    test "sets missing fields to nil" do
      proto = %{
        trip_id: "trip",
        start_time: "12:34:56",
        trip_headsign: "boo"
      }

      actual = TripProperties.new_from_proto(proto, nil)

      expected = %TripProperties{
        source_trip_id: nil,
        new_trip_id: "trip",
        start_date: nil,
        start_time: "12:34:56",
        shape_id: nil,
        trip_headsign: "boo",
        trip_short_name: nil
      }

      assert actual == expected
    end
  end

  describe "new_from_json/2" do
    test "sets source trip_id" do
      json = %{"trip_id" => "newfangled"}
      actual = TripProperties.new_from_json(json, "oldskool")

      expected = %TripProperties{
        source_trip_id: "oldskool",
        new_trip_id: "newfangled"
      }

      assert actual == expected
    end

    test "gets field values from json" do
      json = %{
        "trip_id" => "clone",
        "start_date" => "19991231",
        "start_time" => "12:34:56",
        "shape_id" => "wiggles",
        "trip_headsign" => "boo",
        "trip_short_name" => "SL-2000"
      }

      actual = TripProperties.new_from_json(json, "orig")

      expected = %TripProperties{
        source_trip_id: "orig",
        new_trip_id: "clone",
        start_date: "19991231",
        start_time: "12:34:56",
        shape_id: "wiggles",
        trip_headsign: "boo",
        trip_short_name: "SL-2000"
      }

      assert actual == expected
    end

    test "sets missing fields to nil" do
      json = %{
        "trip_id" => "trip",
        "start_time" => "12:34:56",
        "trip_headsign" => "boo"
      }

      actual = TripProperties.new_from_json(json, nil)

      expected = %TripProperties{
        source_trip_id: nil,
        new_trip_id: "trip",
        start_date: nil,
        start_time: "12:34:56",
        shape_id: nil,
        trip_headsign: "boo",
        trip_short_name: nil
      }

      assert actual == expected
    end
  end

  describe "Concentrate.Mergeable" do
    test "merge/2 takes non-nil values" do
      first =
        TripProperties.new(
          source_trip_id: "trip",
          shape_id: "wiggles",
          trip_short_name: "SL-2000"
        )

      second =
        TripProperties.new(
          source_trip_id: "trip",
          trip_headsign: "boo"
        )

      expected =
        TripProperties.new(
          source_trip_id: "trip",
          shape_id: "wiggles",
          trip_headsign: "boo",
          trip_short_name: "SL-2000"
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end

    test "merge/2 prefers the later start date" do
      late_date =
        TripProperties.new(
          source_trip_id: "trip",
          start_date: "19990801",
          start_time: "09:12:34",
          trip_headsign: "red"
        )

      early_date =
        TripProperties.new(
          source_trip_id: "trip",
          start_date: "19990321",
          start_time: "12:34:56",
          trip_headsign: "green"
        )

      assert Mergeable.merge(late_date, early_date) == late_date
      assert Mergeable.merge(late_date, early_date) == late_date
    end

    test "merge/2 prefers the later start time (on the same date)" do
      late_time =
        TripProperties.new(
          source_trip_id: "trip",
          start_date: "19990321",
          start_time: "12:34:56",
          trip_headsign: "red"
        )

      early_time =
        TripProperties.new(
          source_trip_id: "trip",
          start_date: "19990321",
          start_time: "09:12:34",
          trip_headsign: "green"
        )

      assert Mergeable.merge(late_time, early_time) == late_time
      assert Mergeable.merge(late_time, early_time) == late_time
    end
  end
end
