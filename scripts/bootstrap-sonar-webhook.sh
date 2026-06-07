#!/bin/sh
# Idempotently registers a SonarQube webhook that POSTs the quality-gate
# result back to Jenkins. Without this, `waitForQualityGate abortPipeline:
# true` in the Jenkinsfile parks the build until its 5-minute timeout fires.
#
# Run as a one-shot service in docker-compose (depends_on sonarqube healthy).
# Re-running is safe: existing webhook is a no-op.

set -eu

: "${SONARQUBE_URL:?SONARQUBE_URL is required}"
: "${SONARQUBE_ADMIN_USER:?SONARQUBE_ADMIN_USER is required}"
: "${SONARQUBE_ADMIN_PASSWORD:?SONARQUBE_ADMIN_PASSWORD is required}"
: "${JENKINS_WEBHOOK_URL:?JENKINS_WEBHOOK_URL is required}"

WEBHOOK_NAME="jenkins"
AUTH="${SONARQUBE_ADMIN_USER}:${SONARQUBE_ADMIN_PASSWORD}"

echo "[bootstrap] waiting for SonarQube at ${SONARQUBE_URL} ..."
i=0
until curl -fsS -u "${AUTH}" "${SONARQUBE_URL}/api/system/status" 2>/dev/null \
        | grep -q '"status":"UP"'; do
    i=$((i + 1))
    if [ "${i}" -gt 60 ]; then
        echo "[bootstrap] SonarQube did not become UP within 5 min — giving up." >&2
        exit 1
    fi
    sleep 5
done
echo "[bootstrap] SonarQube is UP."

# Idempotency: if a webhook with this name already exists, exit 0.
existing=$(curl -fsS -u "${AUTH}" "${SONARQUBE_URL}/api/webhooks/list" 2>/dev/null \
    | grep -c "\"name\":\"${WEBHOOK_NAME}\"" || true)

if [ "${existing}" -gt 0 ]; then
    echo "[bootstrap] webhook '${WEBHOOK_NAME}' already exists — nothing to do."
    exit 0
fi

echo "[bootstrap] creating webhook '${WEBHOOK_NAME}' -> ${JENKINS_WEBHOOK_URL}"
curl -fsS -u "${AUTH}" -X POST "${SONARQUBE_URL}/api/webhooks/create" \
    --data-urlencode "name=${WEBHOOK_NAME}" \
    --data-urlencode "url=${JENKINS_WEBHOOK_URL}" \
    >/dev/null
echo "[bootstrap] webhook created."
