#!/usr/bin/env bash
# Run with: ./verify.sh   (it builds YOUR Dockerfile and tests the image against the lab database and cache)
set -uo pipefail
cd "$(dirname "$0")"
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
[ -d pollie ] && docker network inspect ship-net >/dev/null 2>&1 || { echo "Run ./setup.sh first"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
IMG=pollie:lab
# every FROM must name a tag other than latest (stage names defined with AS are fine)
pinned_bases() {
  awk 'toupper($1)=="FROM"{img=$2; for(i=1;i<=NF;i++) if(toupper($i)=="AS") stages[$(i+1)]=1; if(!(img in stages) && img!="scratch"){ if(img !~ /:[^:\/]+$/ || img ~ /:latest$/) bad=1 }} END{exit bad}' Dockerfile
}
cleanup() { docker rm -f -v ship-verify-api ship-verify-worker >/dev/null 2>&1; (cd pollie && git checkout -q -- . 2>/dev/null); }
trap cleanup EXIT
cleanup
L="--label lab=docker-ship-pollie"

echo "== Dockerfile =="
check "Dockerfile has a FROM line (you wrote one)" grep -qE '^FROM ' Dockerfile
check "base images are pinned to a tag (no bare name, no :latest)" pinned_bases
check "a HEALTHCHECK instruction is present" grep -qE '^HEALTHCHECK ' Dockerfile
check "a USER instruction is present" grep -qE '^USER ' Dockerfile

echo "== Build =="
build_log=$(mktemp)
if docker build --progress=plain $L --build-arg APP_VERSION=9.9.9 -f Dockerfile -t $IMG pollie >"$build_log" 2>&1; then echo "PASS  the image builds"; pass=$((pass+1)); else echo "FAIL  the image builds (last lines below)"; failn=$((failn+1)); tail -15 "$build_log"; fi
total=$((total+1))
if ! docker image inspect $IMG >/dev/null 2>&1; then echo; echo "$failn check(s) failed, $pass passed (nothing more can be tested without an image)"; exit 1; fi
size=$(docker image inspect -f '{{.Size}}' $IMG)
check "the image is smaller than 300 MB (yours: $((size/1000000)) MB)" test "$size" -lt 300000000
check "the image does not run as root" bash -c "u=\$(docker image inspect -f '{{.Config.User}}' $IMG); [ -n \"\$u\" ] && [ \"\$u\" != root ] && [ \"\$u\" != 0 ] && [ \"\$(docker run --rm --entrypoint id $IMG -u)\" != 0 ]"
check "the image has a HEALTHCHECK" bash -c "[ -n \"\$(docker image inspect -f '{{if .Config.Healthcheck}}yes{{end}}' $IMG)\" ]"
check "the version label matches the build argument (org.opencontainers.image.version=9.9.9)" bash -c "[ \"\$(docker image inspect -f '{{index .Config.Labels \"org.opencontainers.image.version\"}}' $IMG)\" = 9.9.9 ]"
check "tests, docs and git history are not inside the image" bash -c "docker run --rm --entrypoint sh $IMG -c 'test ! -e /app/tests && test ! -e /app/.git && test ! -e /app/docs'"
check "the app directory is not writable by the app user" bash -c "! docker run --rm --entrypoint sh $IMG -c 'touch /app/x'"
check "no password or connection string is baked into the image" bash -c "! docker history --no-trunc $IMG | grep -qi devpass && ! docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $IMG | grep -q '^DATABASE_URL='"

echo "== Cache =="
echo "# touched by verify.sh" >> pollie/pollie/api/main.py
rb=$(mktemp)
docker build --progress=plain -f Dockerfile -t $IMG pollie >"$rb" 2>&1
check "after changing source code, the dependency install is served from the cache" bash -c "id=\$(grep -E '^#[0-9]+ \[.*(pip|poetry|uv) .*install' '$rb' | head -1 | sed -E 's/^#([0-9]+) .*/\1/'); [ -n \"\$id\" ] && grep -qE \"^#\$id CACHED\" '$rb'"
(cd pollie && git checkout -q -- .)
docker build -q -f Dockerfile -t $IMG --build-arg APP_VERSION=9.9.9 pollie >/dev/null 2>&1

e2e() {
  local p pid oid code
  p=$(curl -s --max-time 5 -XPOST "$API/polls" -H 'Content-Type: application/json' -d '{"question":"Lab?","options":["yes","no"]}')
  pid=$(sed -E 's/^\{"id":([0-9]+).*/\1/' <<<"$p")
  oid=$(grep -oE '"options":\[\{"id":[0-9]+' <<<"$p" | grep -oE '[0-9]+$')
  [ -n "$pid" ] && [ -n "$oid" ] || return 1
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -XPOST "$API/polls/$pid/votes" -H 'Content-Type: application/json' -d "{\"option_id\":$oid,\"voter_id\":\"v1\"}")
  [ "$code" = 202 ] || return 1
  for _ in $(seq 20); do sleep 1; curl -s --max-time 5 "$API/polls/$pid/results" | grep -q '"total_votes":1' && return 0; done
  return 1
}

echo "== It runs =="
env_file=lab.env
docker run -d --name ship-verify-api $L --network ship-net --env-file $env_file -p 127.0.0.1::8000 $IMG >/dev/null
docker run -d --name ship-verify-worker $L --network ship-net --env-file $env_file -p 127.0.0.1::9100 $IMG python -m pollie.worker >/dev/null
for i in $(seq 40); do [ "$(docker inspect -f '{{.State.Health.Status}}' ship-verify-api 2>/dev/null)" = healthy ] && break; sleep 1; done
API="http://127.0.0.1:$(docker port ship-verify-api 8000/tcp | head -1 | sed 's/.*://')"
WRK="http://127.0.0.1:$(docker port ship-verify-worker 9100/tcp | head -1 | sed 's/.*://')"
check "the container's own health check turns healthy" bash -c "[ \"\$(docker inspect -f '{{.State.Health.Status}}' ship-verify-api)\" = healthy ]"
check "/healthz answers and reports the version 9.9.9 (the build argument reached the app)" bash -c "curl -s --max-time 5 $API/healthz | grep -q '9.9.9'"
check "/readyz is ready (the container reaches ship-db and ship-redis)" bash -c "curl -sf --max-time 5 $API/readyz"
check "the same image runs the worker (python -m pollie.worker) and its health port answers" bash -c "curl -sf --max-time 5 $WRK/healthz"
check "end to end: create a poll, vote, and the worker records the vote" e2e
check "the logs of the container are JSON (docker logs shows one object per line)" bash -c "docker logs ship-verify-api 2>&1 | grep -m1 '^{' | python3 -c 'import sys,json; json.loads(sys.stdin.readline())'"

echo
if [ "$failn" -eq 0 ]; then echo "ALL CHECKS PASSED ($pass/$total)"; else echo "$failn check(s) failed, $pass passed"; fi
exit "$failn"
