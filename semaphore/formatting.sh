#!/bin/bash
set -e -x -u

docker run $TAG mix format --check-formatted
