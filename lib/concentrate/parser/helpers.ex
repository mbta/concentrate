defmodule Concentrate.Parser.Helpers do
  @moduledoc """
  Helper functions for the GTFS-RT and GTFS-RT Enhanced parsers.
  """
  require Logger

  defmodule Options do
    @moduledoc false
    @type drop_fields :: %{module => map}
    @type t :: %Options{
            routes: :all | {:ok, MapSet.t()},
            excluded_routes: :none | {:ok, MapSet.t()},
            max_time: :infinity | non_neg_integer,
            drop_fields: drop_fields,
            feed_url: String.t() | nil
          }
    defstruct routes: :all,
              excluded_routes: :none,
              max_time: :infinity,
              drop_fields: %{},
              feed_url: nil
  end

  alias __MODULE__.Options

  @doc """
  Options for parsing a GTFS Realtime file.

  * routes: either :all (don't filter the routes) or {:ok, Enumerable.t} with the route IDs to include
  * excluded_routes: either :none (don't filter) or {:ok, Enumerable.t} with the route IDs to exclude
  * max_time: the maximum time in the future for a stop time update
  * drop_fields: an optional map of struct module to Enumerable.t with fields to drop from the struct
  """
  def parse_options(opts) do
    parse_options(opts, %Options{})
  end

  defp parse_options([{:routes, route_ids} | rest], acc) do
    parse_options(rest, %{acc | routes: {:ok, MapSet.new(route_ids)}})
  end

  defp parse_options([{:excluded_routes, route_ids} | rest], acc) do
    parse_options(rest, %{acc | excluded_routes: {:ok, MapSet.new(route_ids)}})
  end

  defp parse_options([{:drop_fields, %{} = fields} | rest], acc) do
    # create a partial map with the default values from the struct
    fields =
      for {mod, fields} <- fields, into: %{} do
        new_map = Map.take(struct!(mod), fields)
        {mod, new_map}
      end

    parse_options(rest, %{acc | drop_fields: fields})
  end

  defp parse_options([{:max_future_time, seconds} | rest], acc) do
    max_time = :os.system_time(:seconds) + seconds
    parse_options(rest, %{acc | max_time: max_time})
  end

  defp parse_options([{:feed_url, url} | rest], acc) do
    parse_options(rest, %{acc | feed_url: url})
  end

  defp parse_options([_ | rest], acc) do
    parse_options(rest, acc)
  end

  defp parse_options([], acc) do
    acc
  end

  @spec drop_fields(Enumerable.t(), Options.drop_fields()) :: Enumerable.t()
  @doc """
  Given a configuration map, optionally drop some fields from the given enumerable.

  If non-structs are a part of the enumerable, they will be removed.
  """
  def drop_fields(enum, map) when map_size(map) == 0 do
    enum
  end

  def drop_fields(enum, map) do
    for %{__struct__: mod} = struct <- enum do
      case map do
        %{^mod => new_map} ->
          Map.merge(struct, new_map)

        _ ->
          struct
      end
    end
  end

  @spec valid_route_id?(Options.t(), String.t()) :: boolean
  @doc """
  Returns true if the given route ID is valid for the provided options.
  """
  def valid_route_id?(options, route_id)

  def valid_route_id?(%{routes: {:ok, route_ids}}, route_id) do
    route_id in route_ids
  end

  def valid_route_id?(%{excluded_routes: {:ok, route_ids}}, route_id) do
    not (route_id in route_ids)
  end

  def valid_route_id?(_, _) do
    true
  end

  @spec times_less_than_max?(
          non_neg_integer | nil,
          non_neg_integer | nil,
          non_neg_integer | :infinity
        ) :: boolean
  @doc """
  Returns true if the arrival or departure time is less than the provided maximum time.
  """
  def times_less_than_max?(arrival_time, departure_time, max_time)
  def times_less_than_max?(_, _, :infinity), do: true
  def times_less_than_max?(nil, nil, _), do: true
  def times_less_than_max?(time, nil, max), do: time <= max
  def times_less_than_max?(_, time, max), do: time <= max

  @doc """
  Log a warning if the vehicle timestamp is greater than the feed timestamp.
  """
  @spec log_future_vehicle_timestamp(
          Options.t(),
          non_neg_integer | nil,
          non_neg_integer | nil,
          String.t()
        ) :: :ok
  def log_future_vehicle_timestamp(options, feed_timestamp, vehicle_timestamp, vehicle_id)

  def log_future_vehicle_timestamp(options, feed_timestamp, vehicle_timestamp, vehicle_id)
      when is_integer(vehicle_timestamp) and is_integer(feed_timestamp) and
             vehicle_timestamp > feed_timestamp do
    _ =
      Logger.warn(
        "vehicle timestamp after feed timestamp feed_url=#{inspect(options.feed_url)} vehicle_id=#{
          inspect(vehicle_id)
        } feed_timestamp=#{inspect(feed_timestamp)} vehicle_timestamp=#{
          inspect(vehicle_timestamp)
        }"
      )

    :ok
  end

  def log_future_vehicle_timestamp(_options, _feed_timestamp, _vehicle_timestamp, _vehicle_id) do
    :ok
  end
end
