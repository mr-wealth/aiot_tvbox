#!/bin/bash
set -euo pipefail

BUCKET="querplantar-telemetria-lab"
PREFIX="telemetry"
BASE="/var/lib/qp-export"
KEEP_DAYS=7
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
DAY=$(date -u +%Y-%m-%d)

mkdir -p "${BASE}/daily"
TMP=$(mktemp -d "${BASE}/.tmp.XXXXXX")     # mesmo filesystem do destino
trap 'rm -rf "${TMP}"' EXIT                # limpa mesmo se algo falhar

# 1) Snapshot consistente (API de backup do SQLite, dentro do pod)
POD=$(kubectl get pod -n querplantar -l app=qp-backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n querplantar "${POD}" -- python -c \
  "import sqlite3; s=sqlite3.connect('/data/aiot.db'); d=sqlite3.connect('/tmp/snap.db'); s.backup(d); d.close()"
kubectl cp "querplantar/${POD}:/tmp/snap.db" "${TMP}/snap.db"
kubectl exec -n querplantar "${POD}" -- rm -f /tmp/snap.db

# 2) Só substitui o último snapshot se o novo estiver íntegro
[ "$(sqlite3 "${TMP}/snap.db" 'PRAGMA integrity_check;')" = "ok" ]
mv -f "${TMP}/snap.db" "${BASE}/latest.db"

# 3) Um snapshot por dia, com retenção local
[ -f "${BASE}/daily/aiot-${DAY}.db" ] || cp "${BASE}/latest.db" "${BASE}/daily/aiot-${DAY}.db"
find "${BASE}/daily" -name 'aiot-*.db' -mtime +"${KEEP_DAYS}" -delete

# 4) Envia apenas se o Learner Lab estiver ativo
if aws sts get-caller-identity --cli-connect-timeout 5 >/dev/null 2>&1; then
  sqlite3 -header -csv "${BASE}/latest.db" \
    "SELECT * FROM dadohorta ORDER BY data_hora;" | gzip > "${TMP}/dadohorta-${STAMP}.csv.gz"
  aws s3 cp "${TMP}/dadohorta-${STAMP}.csv.gz" "s3://${BUCKET}/${PREFIX}/csv/${STAMP}.csv.gz"
  aws s3 sync "${BASE}/daily/" "s3://${BUCKET}/${PREFIX}/db-daily/"
  echo "Uploaded ${STAMP}"
else
  echo "AWS indisponivel (lab desligado ou credenciais expiradas); snapshot local mantido em ${BASE}"
fi
