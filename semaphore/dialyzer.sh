#!/bin/bash
set -eu

DIALYXIR_PATH=$SEMAPHORE_CACHE_DIR/dialyxir
mkdir -p $DIALYXIR_PATH

docker run -v $DIALYXIR_PATH:/root/_build/dialyxir -v $(realpath $(dirname $0)):/root/semaphore $TAG /root/semaphore/dialyzer_container.sh
