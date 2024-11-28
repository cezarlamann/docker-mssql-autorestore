#!/bin/bash

BASE_IMAGE="cezarlamann/mssql_ar"
TAGS=("2019-latest" "2022-latest" "latest" "latest-ubuntu")

for TAG in "${TAGS[@]}"; do
    docker build --no-cache --build-arg BASE_TAG="$TAG" -t "$BASE_IMAGE:$TAG" .
done