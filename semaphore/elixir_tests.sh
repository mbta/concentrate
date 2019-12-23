#!/bin/bash
set -e -x -u

ci_env=`bash <(curl -s https://codecov.io/env)`
docker run $ci_env $TAG bash -c "mix coveralls.json && bash <(curl -s https://codecov.io/bash)"
