# gtfs_realtime_proto.erl

`gtfs_realtime_proto.erl` is generated from `gtfs_realtime.proto` using
[`gpb`][gpb]. The Erlang code is a parser for wire-format Protobuf data
consisting of messages defined in the `.proto` file. Any time the `.proto` file
changes, you'll need to re-generate the `.erl` file.

`gpb` is a declared dependency of Concentrate, but this process requires `gpb`'s
command-line tools, which you need to build manually (`mix deps.compile` and the
like won't do it for you).

```
cd deps/gpb && make && cd ../..
```

Then use `gpb`'s tool to compile the Erlang proto parser:

```
./deps/gpb/bin/protoc-erl \
  -I src/ gtfs-realtime.proto \
  -c true -defaults-for-omitted-optionals -maps -type \
  -o src/ -modname gtfs_realtime_proto \
  -strbin -maps_unset_optional omitted -v never -Werror -pldefs
```

[gpb]: https://github.com/tomas-abrahamsson/gpb
