# Configuration

Concentrate can be configured either by updating `config/config.exs` file, or by passing in a JSON blob as the CONCENTRATE_JSON environment variable. The latter is ideal for running Concentrate as a service, where you can make one build of the code, but pass different development and production configuration into the build.

## Configuration options

### Sources (required)
* Top-level key: `sources`
* Types
    * `"gtfs_realtime"`: GTFS-RT Protobuf files
    * `"gtfs_realtime_enhanced"`: GTFS-RT Enhanced JSON files
* Each key is a source to fetch from. The value is either a URL (simple configuration) or an object with at least a `"url` key.
* Required options for source value objects
    * `"url"`: the URL to fetch
* Options for source value objects
    * `"fallback_url"`: a URL to use if the parent URL isn’t working (HTTP errors, empty, and/or not updating)
    * `"routes"`: a list of route IDs to include (overrides `"excluded_routes"`)
    *  `"excluded_routes"`: a list of route IDs to exclude
    *  `"max_future_time"`: amount of time (seconds) after which StopTImeUpdates will be ignored
    * `"fetch_after"`: amount of time (milliseconds) to wait between fetches
    * `"headers"`: an object with additional HTTP headers to send. The values can optionally be {“system”: “<ENV_VAR>”} to fetch the header value from the environment.
    * `"drop_fields"`: an object with `"VehiclePosition"`, `"TripDescriptor"`, and/or `"StopTimeUpdate"` keys, and values as a list of fields on those struct. The provided fields will be replace with `null` when being parsed.

### GTFS (required)
* Top-level key: `"gtfs"`
* Required options
    * `"url"`: the URL for the GTFS `.zip` file 

### Sinks
* Top-level key: `"sinks"`
* Types
    * `"s3"`: Amazon Simple Storage Service (S3)
* Options for S3
    * `"bucket"`: S3 bucket to write to
    * `"prefix"`: prepended to the filename before writing to S3


### Alerts
* Top-level key: `"alerts"`
* Options
    * `"url"`: URL to a GTFS-RT Protobuf file with Service Alerts

### Log Level
* Top-level key: `"log_level"`
* Values
    * `"error"`
    * `"warn"`
    * `"info"`
    * `"debug"`

### File Tap
* Top-level key: `"file_tap"`
* Options
    * `"enabled"`: if present, will also write a copy of each file fetched to `<year>/<month>/<day>` in the configured sinks

## Example configuration

    {
      "sources": {
        "gtfs_realtime": {
          "name_1": "url_1",
          "name_2": {
            "url": "url_2",
            "fallback_url": "url_fallback"
          },
          "name_3": {
            "url": "url_3",
            "routes": ["a", "b"]
          },
          "name_4": {
            "url": "url_4",
            "max_future_time": 3600
          },
          "name_5": {
            "url": "url_5",
            "content_warning_timeout": 3600
          },
          "name_6": {
            "url": "url_6",
            "headers": {
              "Authorization": "auth"
            }
          },
          "name_7": {
            "url": "url_7",
            "drop_fields": {
              "VehiclePosition": ["speed"]
            }
          }
        },
        "gtfs_realtime_enhanced": {
          "enhanced_1": {
            "url": "url_3",
            "drop_fields": {
              "TripDescriptor": ["start_time"]
            }
          }
        }
      },
      "gtfs": {
        "url": "gtfs_url"
      },
      "alerts": {
        "url": "alerts_url"
      },
      "sinks": {
        "s3": {
          "bucket": "s3-bucket",
          "prefix": "bucket_prefix"
        }
      },
      "file_tap": {
        "enabled": true
      }
    }

