#!/usr/bin/env bash
# Removes everything the lab created. Run:  ./teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
ids=$(docker ps -a -q --filter label=lab=docker-ship-pollie)
extra=$(docker ps -a --format '{{.Names}}' | grep -E '^ship-' || true)
[ -n "$ids" ] && docker rm -f -v $ids >/dev/null
[ -n "$extra" ] && docker rm -f -v $extra >/dev/null
docker volume ls -q --filter label=lab=docker-ship-pollie | xargs -r docker volume rm >/dev/null 2>&1 || true
docker network rm ship-net >/dev/null 2>&1 || true
docker network ls -q --filter label=lab=docker-ship-pollie | xargs -r docker network rm >/dev/null 2>&1 || true
# the images you built (anything tagged pollie:*) and the labelled ones
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^pollie:' | xargs -r docker rmi -f >/dev/null 2>&1 || true
docker images -q --filter label=lab=docker-ship-pollie | xargs -r docker rmi -f >/dev/null 2>&1 || true
docker builder prune -f --filter label=lab=docker-ship-pollie >/dev/null 2>&1 || true
rm -rf pollie
echo "Removed the containers, network, images and the cloned source. Now run ./verify-teardown.sh to prove it."
echo "(The base images python, postgres and redis stay: they are a cache.)"
