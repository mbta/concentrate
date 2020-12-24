# Concentrate Architecture

Overall, Concentrate is modeled as a [GenStage](https://github.com/elixir-lang/gen_stage) pipeline.

## Data

Throughout the pipeline, data is represented as one of three structs:

* `TripDescriptor`: basic trip information like ID, route ID, and direction
* `VehiclePosition`: where the vehicle is, both latitude/longitude and on the trip
* `StopTimeUpdate`: a prediction about when a vehicle will arrive/depart a stop

## Producer.HTTPoison

At the top of the pipeline are a set of Producer.HTTPoison stages. Each one is
responsible for a single file, as well as handling caching and parsing. We
fetch no more frequently than every 5 seconds, to avoid overloading the
remote systems. Once fetched, they're parsed and passed along down the pipeline.

## MergeFilter

All of the parsed data goes through MergeFilter, which is responsible for
combining the parsed data and doing any post-processing.

Each type of struct is responsible for merging, through an implementation of
the Mergeable protocol.

Filters implement the Filter behavior. Each one can modify or remove the
provided struc. Some filters depend on outside data such as alerts or GTFS:
those filters maintain external state and refer to it during the filtering.

After the first pass of filtering, the data are grouped by their trip
ID. This more closely matches the GTFS-RT format, by having a TripDescriptor
grouped with the VehiclePositions and StopTimeUpdates for that trip.

The groups are then passed through modules implementing the GroupFilter
behavior. These filters are more holistic, looking at the entire state of the
trip to filter or adjust the group.

## Encoder

The merged/filtered/grouped data are passed to the Encoder stages, one per file:

* TripUpdates.pb
* TripUpdates_enhanced.json
* VehiclePositions.pb

The encoders implement the Encoder protocol, and turn the list of groups
into a binary.

## Sinks

At the bottom of the pipeline are the Sinks. They're responsible for sending
the encoded files to their final destination. For development,
Sink.Filesystem writes the files to a local directory. In production, Sink.S3
writes them to an S3 bucket.
