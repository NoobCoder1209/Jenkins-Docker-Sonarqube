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
# A 401 here means the admin password has been rotated (almost certainly via the
# UI on a prior boot) and the persisted Sonar volume already has the webhook —
# treat that as "nothing to do" rather than failing the bootstrap container.
list_status=$(curl -s -o /tmp/webhook_list.json -w '%{http_code}' \
    -u "${AUTH}" "${SONARQUBE_URL}/api/webhooks/list")

case "${list_status}" in
    200)
        if grep -q "\"name\":\"${WEBHOOK_NAME}\"" /tmp/webhook_list.json; then
            echo "[bootstrap] webhook '${WEBHOOK_NAME}' already exists — nothing to do."
            exit 0
        fi
        ;;
    401)
        echo "[bootstrap] 401 on /api/webhooks/list — admin password has likely been rotated."
        echo "[bootstrap] assuming the webhook was provisioned on a prior boot. Skipping."
        echo "[bootstrap] If the webhook is missing, set SONARQUBE_ADMIN_PASSWORD in your .env"
        echo "[bootstrap] and re-run: docker compose run --rm bootstrap"
        exit 0
        ;;
    *)
        echo "[bootstrap] unexpected status ${list_status} from /api/webhooks/list" >&2
        cat /tmp/webhook_list.json >&2 || true
        exit 1
        ;;
esac

echo "[bootstrap] creating webhook '${WEBHOOK_NAME}' -> ${JENKINS_WEBHOOK_URL}"
curl -fsS -u "${AUTH}" -X POST "${SONARQUBE_URL}/api/webhooks/create" \
    --data-urlencode "name=${WEBHOOK_NAME}" \
    --data-urlencode "url=${JENKINS_WEBHOOK_URL}" \
    >/dev/null
echo "[bootstrap] webhook created."
