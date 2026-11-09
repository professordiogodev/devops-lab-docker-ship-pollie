#!/usr/bin/env bash
# Prepares the lab: gets the application source, and starts a database and a cache to test your image against.
# Run:  ./setup.sh   (no sudo)
set -uo pipefail
cd "$(dirname "$0")"
command -v docker >/dev/null || { echo "docker is not installed or not on PATH"; exit 1; }
command -v git >/dev/null || { echo "git is not installed"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running (or your user may not use it). Start Docker and try again."; exit 1; }
L="--label lab=docker-ship-pollie"

if docker network inspect ship-net >/dev/null 2>&1; then echo "The lab is already set up. Run ./teardown.sh first to start over."; exit 1; fi

if [ ! -d pollie/.git ]; then
  echo "Getting the Pollie source (v0.1.0)..."
  git clone -q --depth 1 --branch v0.1.0 https://github.com/professordiogodev/pollie.git pollie 2>/dev/null || { echo "could not clone Pollie (network?)"; exit 1; }
fi

echo "Pulling images (first run only)..."
for img in python:3.12 python:3.12-slim postgres:16-alpine redis:7-alpine; do docker pull -q "$img" >/dev/null || { echo "could not pull $img"; exit 1; }; done

docker network create $L ship-net >/dev/null
docker run -d --name ship-db $L --network ship-net -e POSTGRES_PASSWORD=devpass -e POSTGRES_DB=pollie postgres:16-alpine >/dev/null
docker run -d --name ship-redis $L --network ship-net redis:7-alpine >/dev/null
for i in $(seq 30); do docker exec ship-db pg_isready -U postgres -d pollie >/dev/null 2>&1 && break; sleep 1; done
docker exec ship-redis redis-cli ping >/dev/null 2>&1 || sleep 2

echo
echo "Ready:"
echo "  application source : ./pollie  (a git clone; do not edit it, you are packaging it)"
echo "  database           : ship-db    (PostgreSQL, on network ship-net)"
echo "  cache and queue    : ship-redis (Redis, on network ship-net)"
echo "  their settings     : lab.env    (use: docker run --env-file lab.env ...)"
echo "  a bad Dockerfile   : naive/Dockerfile"
echo
echo "Next: read the README, then ./verify.sh whenever you want to see where you are."
