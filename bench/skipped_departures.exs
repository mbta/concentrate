alias Concentrate.{TripDescriptor, StopTimeUpdate}

td = TripDescriptor.new([])
five_skipped = for _ <- 0..4 do
  StopTimeUpdate.new(schedule_relationship: :SKIPPED)
end
one_skipped = Enum.take(five_skipped, 1)
ten_normal = for _ <- 0..9 do
  StopTimeUpdate.new(departure_time: 5)
end

Benchee.run(
  %{
    "original": &Concentrate.GroupFilter.SkippedDepartures.filter/1,
    "new": &Concentrate.GroupFilter.SkippedDeparturesNew.filter/1
    #"enum": fn -> Concentrate.Merge.merge(Enum.flat_map(data, &elem(&1, 1))) end,
    ##"stream": fn -> Concentrate.Merge.merge(Stream.flat_map(data, &elem(&1, 1))) end,
    #"flatten": fn -> Concentrate.Merge.merge(List.flatten(Map.values(data))) end,
    #"new": fn -> Concentrate.Merge.merge_new(Enum.flat_map(data, &elem(&1, 1))) end
    #"ets": fn -> Concentrate.Merge.merge_ets(data) end
  },
  inputs: %{
    no_skipped: {td, [], ten_normal},
    one_skipped_end: {td, [], ten_normal ++ one_skipped},
    one_skipped: {td, [], ten_normal ++ one_skipped ++ ten_normal},
    five_skipped_end: {td, [], ten_normal ++ five_skipped},
    five_skipped: {td, [], ten_normal ++ five_skipped ++ ten_normal}
  },
  print: [fast_warning: false],
  time: 5)
