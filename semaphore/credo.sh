#!/bin/bash
set -e -x -u

docker run $TAG mix credo --strict
