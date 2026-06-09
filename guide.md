# Guide: running and verifying the Jenkins-Docker-Sonarqube demo

> **Last verified:** 2026-06-09 against commit `adb1452` (current `main`).
> Ran `docker compose up -d --build`, generated a SonarQube token, recreated
> Jenkins to pick it up, triggered the seed `demo` pipeline. Build #1 finished
> in **64 s** with all 9 stages green, **SonarQube Quality Gate PASSED**, and
> the resulting Docker image `jenkins-docker-sonarqube-demo:1-<sha>` was built
> on the host.

This file is for someone who has never touched the repo. It explains the bare
minimum to run the demo, prove it worked, and recover from the most common
failures. The README has the marketing version; this file has the dry version.

## 1. Prerequisites

You need **only one** thing on your host:

| Tool | Minimum version | Notes |
| --- | --- | --- |
| Docker | 24+ (with Compose v2) | Tested with Docker `29.5.2` + Compose `v5.1.4`. Docker Desktop, OrbStack, Colima, or a Linux daemon are all fine. |

Optional but useful while debugging:

- `curl` — for hitting the Jenkins / SonarQube APIs from a terminal.
- `python3` — for parsing the JSON those APIs return.
- A web browser — for the Jenkins UI at `http://localhost:8080` and SonarQube
  at `http://localhost:9000`.

You do **not** need Python, Java, Node, ruff, pytest, sonar-scanner, or any
Jenkins plugin installed locally. Everything runs inside containers.

You also need free TCP ports `8080`, `9000`, and `50000` on the host. If
something else is already listening, see [Failure modes](#5-common-failure-modes).

## 2. End-to-end run, in order

These commands work copy-paste from the repo root after `git clone`. Open a
terminal, `cd` into the repo, then:

```bash
# 1. Bring up the stack. First boot pulls images and builds the custom Jenkins
#    image; expect 3–4 minutes on a cold cache.
docker compose up -d --build

# 2. Wait for everything to report healthy. The bootstrap container is one-shot
#    and exits 0 once the SonarQube webhook is registered — that is expected.
#    `-a` is required to see exited containers.
docker compose ps -a

# 3. Confirm the SonarQube → Jenkins webhook was registered.
docker compose logs bootstrap
# Expected last line: "[bootstrap] webhook created."  or  "already exists"
```

At this point **don't click "Build Now" yet**. The seed pipeline needs a
SonarQube auth token, and a fresh stack ships with a placeholder
(`SONARQUBE_TOKEN=changeme`). Generate the real one:

```bash
# 4. Open SonarQube in a browser:  http://localhost:9000
#    Log in:  admin / admin
#    SonarQube forces a password change on first login. Pick a new one and
#    keep it — you'll need it in the .env in step 5.
#
#    Then:  My Account  →  Security  →  Generate Tokens
#           Type: User Token  (or Project Analysis Token scoped to
#                              jenkins-docker-sonarqube)
#    Copy the squ_xxxxx... value.

# 5. Drop both secrets into a local .env at the repo root. .env is gitignored.
cat > .env <<'EOF'
SONARQUBE_TOKEN=squ_<paste-the-token-from-step-4>
SONARQUBE_ADMIN_PASSWORD=<the-new-sonar-admin-password-from-step-4>
EOF

# 6. Recreate the Jenkins container so it re-reads JCasC with the new token.
docker compose up -d --force-recreate jenkins

# 7. Wait for Jenkins to come back healthy (about 30 s).
docker compose ps jenkins
```

Now trigger the pipeline:

```bash
# 8. Open Jenkins in a browser:  http://localhost:8080
#    Log in:  admin / admin
#    Click the "demo" job, then "Build Now".
#
#    OR — same effect, no browser:
CRUMB=$(curl -s -u admin:admin -c /tmp/jc.txt \
        'http://localhost:8080/crumbIssuer/api/json' \
        | python3 -c "import sys,json;print(json.load(sys.stdin)['crumb'])")
curl -s -u admin:admin -b /tmp/jc.txt -H "Jenkins-Crumb: $CRUMB" \
     -X POST 'http://localhost:8080/job/demo/build' \
     -w 'HTTP %{http_code}\n' -o /dev/null
# Expect: HTTP 201
```

Watch it run:

```bash
# 9. Poll the build until it finishes (or watch in the Jenkins UI).
curl -s -u admin:admin 'http://localhost:8080/job/demo/lastBuild/api/json' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); \
print('building:', d.get('building'), '\nresult:', d.get('result'))"
# When result=SUCCESS and building=False, the demo is done.
```

Tear it down when finished:

```bash
# 10. Stop containers and wipe their named volumes (jenkins_home, sonarqube_data,
#     postgres data). Drop -v if you want to keep state for the next run.
docker compose down -v
rm -f .env
```

## 3. What every directory and file does

```
.
├── app/                        # Demo Flask app — what gets scanned
│   ├── __init__.py             # Empty Python package marker (load-bearing)
│   ├── main.py                 # App factory + global JSON error handler
│   ├── routes.py               # /, /health, /echo (Pydantic-validated), /info
│   │                           # /info has intentional Sonar findings: long
│   │                           # function, unused local, debug print()
│   ├── models.py               # Pydantic request schemas (EchoRequest)
│   └── healthcheck.py          # Returns {"status":"ok"} for /health
│
├── tests/                      # 9 pytest cases, ~97 % coverage on app/
│   ├── __init__.py             # Empty package marker (load-bearing)
│   ├── conftest.py             # Flask test-client fixture
│   ├── test_routes.py          # Happy path + 400 + 404 contract checks
│   └── test_healthcheck.py     # Direct unit test on the helper
│
├── jenkins/                    # The custom Jenkins image
│   ├── Dockerfile              # FROM jenkins/jenkins:lts + docker-cli + python3
│   │                           # + plugins via jenkins-plugin-cli + JCasC
│   ├── plugins.txt             # 20 plugins (JCasC, Job DSL, Pipeline,
│   │                           # SonarQube Scanner, Docker, Git, Blue Ocean)
│   └── jenkins.yaml            # Configuration as Code — admin user, Sonar
│                               # server, Sonar Scanner CLI tool, seed
│                               # pipelineJob('demo') pulling this Jenkinsfile
│
├── scripts/
│   └── bootstrap-sonar-webhook.sh   # Idempotent: registers Sonar→Jenkins
│                               # webhook so waitForQualityGate doesn't hang.
│                               # Handles 401 on rotated admin password.
│
├── docs/
│   └── screenshots/
│       ├── jenkins-pipeline.png    # Blue Ocean view, all stages green
│       └── sonarqube-dashboard.png # Quality Gate Passed, all measures A
│
├── docker-compose.yml          # 4 services: postgres + sonarqube + jenkins
│                               # + bootstrap. Healthchecks, depends_on:
│                               # service_healthy, named volumes.
├── Dockerfile                  # Multi-stage app image. Builder installs deps
│                               # into a venv; slim runtime is non-root uid 1001
│                               # with HEALTHCHECK on /health.
├── .dockerignore               # Excludes .git, tests/, venv, CI configs.
├── Jenkinsfile                 # Declarative pipeline used by the seed job.
│                               # 7 stages: Checkout → Setup Python → Lint →
│                               # Test → SonarQube Analysis → Quality Gate →
│                               # Build Image.
├── sonar-project.properties    # Sonar projectKey + sources/tests + Python
│                               # version + coverage path. NO host_url / token
│                               # (withSonarQubeEnv injects them).
├── pyproject.toml              # ruff config (rule selection) + pytest config.
├── requirements.txt            # flask, pydantic — runtime only.
├── requirements-dev.txt        # +pytest, pytest-cov, ruff — dev only.
├── README.md                   # Public-facing overview.
├── guide.md                    # This file.
└── LICENSE                     # MIT.
```

## 4. Environment variables and where they go

There are no required env vars on a fresh first run — every variable has a
sensible demo-only default baked into `docker-compose.yml`. The variables you
**will** want to override live in a local `.env` file at the repo root.
`.env` is gitignored.

| Variable | Used by | Default | Override when |
| --- | --- | --- | --- |
| `SONARQUBE_TOKEN` | `jenkins` (passed into JCasC's `sonarqube-token` credential) | `changeme` (placeholder, will 401) | **Always after first boot.** Generate via the Sonar UI (My Account → Security → Generate Tokens). |
| `SONARQUBE_ADMIN_PASSWORD` | `bootstrap` (used to call `/api/webhooks/list`) | `admin` | **After you change the Sonar admin password** (Sonar forces a change on first login). Without this, re-running `bootstrap` 401s. |
| `JENKINS_ADMIN_PASSWORD` | `jenkins` JCasC | `admin` | Pretty much never for a demo. Set it if you want the admin login to be anything other than `admin/admin`. |
| `GIT_REPO_URL` | `jenkins` JCasC seed job | `https://github.com/NoobCoder1209/Jenkins-Docker-Sonarqube.git` | If you forked the repo and want the seed pipeline to pull from your fork. |

Example `.env`:

```bash
SONARQUBE_TOKEN=squ_4f7b5250f393ad7e0f9d66976c77d13013d720aa
SONARQUBE_ADMIN_PASSWORD=ChangedOnFirstLogin!
```

There are **no real secrets** in the repo. The `admin / admin` defaults and the
`changeme` token are clearly marked `# demo-only` in `docker-compose.yml` and
`jenkins/jenkins.yaml`.

## 5. How to verify it actually worked

After the build finishes (step 9 above), confirm each of these:

```bash
# A. Pipeline reports SUCCESS.
curl -s -u admin:admin 'http://localhost:8080/job/demo/lastBuild/api/json' \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('result'))"
# Expect: SUCCESS

# B. All 9 stages individually green. (Output: stage name, status, duration.)
curl -s -u admin:admin 'http://localhost:8080/job/demo/lastBuild/wfapi/describe' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); \
[print(f\"  {s['name']:30s} {s['status']:10s} {s.get('durationMillis',0)/1000:.1f}s\") \
 for s in d.get('stages',[])]"
# Expect: SUCCESS on every line:
#   Declarative: Checkout SCM   SUCCESS   ~5s
#   Checkout                    SUCCESS   <1s
#   Setup Python                SUCCESS   ~30s
#   Lint                        SUCCESS   <1s
#   Test                        SUCCESS   <1s
#   SonarQube Analysis          SUCCESS   ~9s
#   Quality Gate                SUCCESS   ~3s
#   Build Image                 SUCCESS   ~4-22s (depends on Docker layer cache)
#   Declarative: Post Actions   SUCCESS   <1s

# C. SonarQube received the analysis and returned Passed.
curl -s -u admin:admin \
    'http://localhost:9000/api/qualitygates/project_status?projectKey=jenkins-docker-sonarqube' \
    | python3 -m json.tool
# Expect: "status": "OK" under "projectStatus".

# D. The Docker image was built on the host.
docker images | grep jenkins-docker-sonarqube-demo
# Expect: at least one row with the IMAGE ID and a tag like 1-<short-sha>.
```

A green tick on all four = the demo did exactly what the README claims.

If you want a **screenshot** of what success looks like, the README's "Demo"
section already references two committed PNGs:

- [`docs/screenshots/jenkins-pipeline.png`](docs/screenshots/jenkins-pipeline.png) — Blue Ocean view, all 7 stages green.
- [`docs/screenshots/sonarqube-dashboard.png`](docs/screenshots/sonarqube-dashboard.png) — SonarQube Overview with Quality Gate `Passed` and four A measures.

Both are at the paths above relative to the repo root and are linked from
`README.md` line 17. No separate screenshot capture is needed for this PR.

## 6. Common failure modes and their fixes

### "Pipeline hangs on Quality Gate"

The bootstrap webhook never registered, so SonarQube has nothing to POST back
to and Jenkins parks the build until its 5-minute timeout fires. Check:

```bash
docker compose logs bootstrap
```

If the last line is **not** `[bootstrap] webhook created.` or `already exists`,
re-run the bootstrap container (after fixing `.env` if the admin password was
rotated):

```bash
docker compose run --rm bootstrap
```

### "SonarQube Analysis stage fails with HTTP 401"

The pipeline is using the `changeme` placeholder token. You skipped step 5.
Set `SONARQUBE_TOKEN` in `.env` (see [§4](#4-environment-variables-and-where-they-go))
and run `docker compose up -d --force-recreate jenkins`.

### "Build Image stage fails with `docker: not found`"

You're on an older Debian base where `docker-cli` isn't a binary package. The
current `jenkins/Dockerfile` targets Debian trixie+. If your `jenkins/jenkins:lts`
is older (bookworm), edit `jenkins/Dockerfile` and replace the line:

```dockerfile
docker-cli \
```

with:

```dockerfile
docker.io \
```

then `docker compose up -d --build jenkins`. The `docker.io` package on
bookworm includes both the daemon and the client, even though on trixie+ the
client is split out into `docker-cli`.

### "SonarQube container shows (unhealthy) but the UI works"

This used to happen with a `wget`-based healthcheck against the Sonar 26
image, which doesn't ship `wget`. The current `docker-compose.yml` uses `curl`
(which Sonar 26 does ship). If you see this on a forked or older copy, change
the sonarqube `healthcheck.test` to:

```yaml
test: ["CMD-SHELL", "curl -fsS http://localhost:9000/api/system/status | grep -q '\"status\":\"UP\"'"]
```

### "Ports 8080 / 9000 already in use"

Edit `docker-compose.yml` and change the host side of the `ports:` mappings
(e.g. `"18080:8080"` instead of `"8080:8080"`). If you remap Jenkins, also
update `JENKINS_WEBHOOK_URL` in the `bootstrap` service's `environment`
block — that's the URL SonarQube POSTs the gate result to.

### "SonarQube logs `vm.max_map_count [...] is too low`"

Linux only. Either:

```bash
sudo sysctl -w vm.max_map_count=524288
```

or uncomment the `sysctls:` block under the `sonarqube` service in
`docker-compose.yml`. Docker Desktop (macOS / Windows) handles this in its
embedded VM and needs no action.

### "First boot takes forever"

That's normal. SonarQube 26 community runs Elasticsearch as a sub-process and
indexes itself on the empty `sonarqube_data` volume the first time. Expect
2–3 minutes for `(healthy)`. Tail with `docker compose logs -f sonarqube` and
wait for `SonarQube is operational`.

### "I rotated the Sonar admin password and now bootstrap fails"

The bootstrap script checks `/api/webhooks/list` with `admin:admin` by
default. If the password has been changed, set `SONARQUBE_ADMIN_PASSWORD` in
`.env` to match, then run `docker compose run --rm bootstrap`. The script
also degrades to "skip" on a 401, on the assumption that the webhook was
already provisioned on a prior boot — so an unfixed 401 is annoying but not
catastrophic.

### "Reset everything and start fresh"

```bash
docker compose down -v       # wipes named volumes (jenkins_home, sonarqube_*, pg_data)
docker compose up -d --build
```

You will need to regenerate the Sonar token after the volume wipe, since
SonarQube starts from an empty database.
