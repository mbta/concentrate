alias Concentrate.{TripDescriptor, VehiclePosition, StopTimeUpdate}
alias Concentrate.Merge.{Table, TableOrig}

data = for file <- Path.wildcard("/tmp/*.pb") do
  Concentrate.Parser.GTFSRealtime.parse(File.read!(file), [])
end |> List.flatten
sort_fn = fn x ->
  case x do
    %TripDescriptor{} -> 0
    %VehiclePosition{} -> 1
    %StopTimeUpdate{} -> 2
    _ -> 4
  end
end

Benchee.run(
  %{
    "original": fn -> TableOrig.new() |> TableOrig.add(:source) |> TableOrig.update(:source, data) |> TableOrig.items |> Enum.sort_by(&Concentrate.Mergeable.sort_key/1) end,
    # "enum": fn -> Concentrate.Merge.merge(Enum.flat_map(data, &elem(&1, 1))) end,
    # "stream": fn -> Concentrate.Merge.merge(Stream.flat_map(data, &elem(&1, 1))) end,
    # "flatten": fn -> Concentrate.Merge.merge(List.flatten(Map.values(data))) end,
    "new": fn -> Table.new() |> Table.add(:source) |> Table.update(:source, data) |> Table.items end
    #proto": fn -> Concentrate.MergeProto.merge(data) end,
    #"ets": fn -> Concentrate.Merge.merge_ets(data) end
  },
  time: 10)
