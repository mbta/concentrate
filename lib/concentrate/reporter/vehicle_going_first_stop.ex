defmodule Concentrate.Reporter.VehicleGoingFirstStop do
  @moduledoc false
  @behaviour Concentrate.Reporter
  require Logger
  alias Concentrate.{VehiclePosition, StopTimeUpdate, TripUpdate}

  @impl Concentrate.Reporter
  def init do
    :ok
  end

  @impl Concentrate.Reporter
  def log(groups, state) do
    for {tu, vps, stus} <- groups,
        tu != nil,
        stus != [],
        vp <- vps do
      if VehiclePosition.status(vp) != :STOPPED_AT do
        stu = hd(stus)
        first_stop_sequence = StopTimeUpdate.stop_sequence(stu)
        vp_stop_sequence = VehiclePosition.stop_sequence(vp)

        if vp_stop_sequence < first_stop_sequence do
          Logger.error("#{inspect(TripUpdate.route_id(tu))}")
        end
      end
    end

    {[], state}
  end
end
