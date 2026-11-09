#!/usr/bin/env bash
rc=0
if [ -s Dockerfile ] && grep -qE '^FROM ' Dockerfile && grep -qE '^USER ' Dockerfile && grep -qE '^HEALTHCHECK ' Dockerfile; then echo "- ✅ Dockerfile has FROM, USER and HEALTHCHECK"
else echo "- ❌ Dockerfile must have FROM, USER and HEALTHCHECK instructions"; rc=1; fi
grep -qE '^ALL CHECKS PASSED \(' SUBMISSION.md && echo "- ✅ SUBMISSION.md shows ALL CHECKS PASSED" || { echo "- ❌ paste the verify.sh output ('ALL CHECKS PASSED') into SUBMISSION.md"; rc=1; }
exit $rc
