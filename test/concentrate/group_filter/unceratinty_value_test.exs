defmodule Concentrate.GroupFilter.UncertaintyValueTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.UncertaintyValue
  alias Concentrate.StopTimeUpdate
  alias Concentrate.TripDescriptor

  describe "filter/1" do
    test "populates uncertainty in StopTimeUpdate based on update_type value of mid_trip" do
      td = TripDescriptor.new(update_type: "mid_trip")

      stus = [
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil)
      ]

      {^td, [], processed_stus} = filter({td, [], stus})

      assert Enum.all?(processed_stus, fn procced_stu ->
               StopTimeUpdate.uncertainty(procced_stu) == 60
             end)
    end

    test "populates uncertainty in StopTimeUpdate based on update_type value of at_terminal" do
      td = TripDescriptor.new(update_type: "at_terminal")

      stus = [
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil)
      ]

      {^td, [], processed_stus} = filter({td, [], stus})

      assert Enum.all?(processed_stus, fn procced_stu ->
               StopTimeUpdate.uncertainty(procced_stu) == 120
             end)
    end

    test "populates uncertainty in StopTimeUpdate based on update_type value of reverse_trip" do
      td = TripDescriptor.new(update_type: "reverse_trip")

      stus = [
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil),
        StopTimeUpdate.new(uncertainty: nil)
      ]

      {^td, [], processed_stus} = filter({td, [], stus})

      assert Enum.all?(processed_stus, fn procced_stu ->
               StopTimeUpdate.uncertainty(procced_stu) == 360
             end)
    end

    test "maintains uncertainty in StopTimeUpdate if update_type is not valid" do
      td = TripDescriptor.new(update_type: nil)

      stus = [
        StopTimeUpdate.new(uncertainty: 60),
        StopTimeUpdate.new(uncertainty: 60),
        StopTimeUpdate.new(uncertainty: 60)
      ]

      {^td, [], processed_stus} = filter({td, [], stus})

      assert Enum.all?(processed_stus, fn procced_stu ->
               StopTimeUpdate.uncertainty(procced_stu) == 60
             end)
    end
  end
end
