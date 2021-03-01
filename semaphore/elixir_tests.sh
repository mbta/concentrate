#!/bin/bash
set -e -x -u

env MIX_ENV=test mix do compile --force --warnings-as-errors, test --cover
