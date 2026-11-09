#!/usr/bin/env bash
# Proves the lab environment is gone. Run with: ./verify-teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
none() { [ -z "$(eval "$1")" ]; }
check "no container named ship-*" none "docker ps -a --format '{{.Names}}' | grep -E '^ship-'"
check "no container with the lab label" none "docker ps -a -q --filter label=lab=docker-ship-pollie"
check "the network ship-net is gone" bash -c "! docker network inspect ship-net"
check "no image tagged pollie:*" none "docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^pollie:'"
check "no image with the lab label" none "docker images -q --filter label=lab=docker-ship-pollie"
check "the cloned source ./pollie is removed" bash -c "[ ! -e pollie ]"
echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$total)"; else echo "NOT CLEAN: $failn leftover(s). Finish the tear down steps and run this again."; fi
exit "$failn"
