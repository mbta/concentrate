#!/bin/bash
set -e

export TAG=concentrate:test-$BRANCH_NAME
docker build -f Dockerfile.test -t $TAG .
