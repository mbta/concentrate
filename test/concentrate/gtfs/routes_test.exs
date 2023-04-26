defmodule Concentrate.GTFS.RoutesTest do
  @moduledoc false
  use ExUnit.Case
  alias Concentrate.GTFS.Routes

  @routes """
  route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_url,route_color,route_text_color,route_sort_order
  CR-Middleborough,1,,Middleborough/Lakeville Line,Commuter Rail,2,https://www.mbta.com/schedules/CR-Middleborough,80276C,FFFFFF,20009
  CR-Worcester,1,,Framingham/Worcester Line,Commuter Rail,2,https://www.mbta.com/schedules/CR-Worcester,80276C,FFFFFF,20003
  """

  defp supervised(_) do
    start_supervised(Routes)

    event = [{"routes.txt", @routes}]

    Routes.handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "route_type/1" do
    setup :supervised

    test "returns the type for a given route" do
      assert Routes.route_type("CR-Middleborough") == 2
      assert Routes.route_type("CR-Worcester") == 2
    end
  end
end
