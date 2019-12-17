#!/bin/bash
set -e -x -u

env MIX_ENV=test mix do compile --force --warnings-as-errors, coveralls.json
bash <(curl -s https://codecov.io/bash)
