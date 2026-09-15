data = Concentrate.Parser.GTFSRealtime.parse(File.read!("/tmp/TripDescriptors.pb"), [])

Benchee.run(
  %{
    "original": &Concentrate.Encoder.GTFSRealtimeHelpers.group/1,
    "new": &Concentrate.Encoder.GTFSRealtimeHelpers.group_new/1
    #"enum": fn -> Concentrate.Merge.merge(Enum.flat_map(data, &elem(&1, 1))) end,
    ##"stream": fn -> Concentrate.Merge.merge(Stream.flat_map(data, &elem(&1, 1))) end,
    #"flatten": fn -> Concentrate.Merge.merge(List.flatten(Map.values(data))) end,
    #"new": fn -> Concentrate.Merge.merge_new(Enum.flat_map(data, &elem(&1, 1))) end
    #"ets": fn -> Concentrate.Merge.merge_ets(data) end
  },
  inputs: %{data: data},
  time: 10)
