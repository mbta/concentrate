#!/bin/bash
set -e

DIALYXIR_PATH=$SEMAPHORE_CACHE_DIR/dialyxir
mkdir -p $DIALYXIR_PATH

docker run -v $DIALYXIR_PATH:/root/_build/dialyxir $TAG bash /root/semaphore/dialyzer_container.sh
