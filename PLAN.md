# `Jenkins-Docker-Sonarqube` — Execution Plan (Full Rebuild)

## How to use this plan

You are the build session for this repo. Read this file end-to-end, then start executing immediately.

**Working agreement:**

1. **Start without waiting.** Begin Phase 1 in the *Subagent playbook* below.
2. **Always ask the user about business decisions and business logic.** Most importantly: what this repo *should be* — see "Business decisions". The current contents (a static Bootstrap gym website) have nothing to do with the repo name.
3. **Ask the user when you are genuinely blocked.**
4. **Do not ask the user about engineering details.** Internal Jenkins job XML, SonarQube quality gate IDs, file layout — your call.
5. **Use subagents aggressively.** Default to the playbook below.
6. **TaskCreate / TaskUpdate everything.**
7. **Pattern 3 only.** No live Jenkins or SonarQube instance. Repo ships configs + screenshots of a local docker-compose stack.
8. **Follow shared standards** (MIT, README, CI, topics, **flip public when verification passes — repo is currently public, so it should NEVER be visibly broken on `main`. Use a `rebuild/*` branch and merge only when ready.**).
9. **All `Agent` tool calls must pass `model: "opus"`.**
10. **Off-limits forever:** SAP-internal references, `~/.claude/`, RCA content.

## Subagent playbook (this repo)

Lots of toolchain glue. 4 in research, 2 in review.

**Phase 1 — Research (parallel):**
- `Explore` (Opus): "Find a current minimal Jenkins-as-Code setup using JCasC (`jenkins.yaml`) + a job DSL or pipeline-as-code seed job, runnable via docker-compose. Return ≤200-line snippet."
- `Explore` (Opus): "Find current docker-compose recipe for Jenkins + SonarQube + Postgres (SonarQube backend) including healthchecks and persistent volumes. Return complete compose file."
- `Explore` (Opus): "Find the canonical `Jenkinsfile` that builds a Python or Node app, runs unit tests with coverage, runs SonarQube analysis with quality gate, and pushes a Docker image to a registry. Return ≤120-line pipeline."
- `Explore` (Opus): "Find the SonarQube Scanner CLI invocation pattern + `sonar-project.properties` for a Python and a Node project. Return both as snippets."

**Phase 2 — Design (single):**
- `Plan` (Opus): "Given research, the user's business decisions, and this PLAN.md, propose the rebuild file tree, the demo app to scan, the build order, and a verification flow. Return as a checklist."

**Phase 3 — Build:** main session writes the rebuild on a `rebuild/v1` branch. `Explore` for tooling questions.

**Phase 4 — Review (parallel):**
- `code-reviewer` (Opus): "Review for: docker-compose health/persistence correctness, JCasC reproducibility (no manual UI clicks), SonarQube quality gate correctness, Jenkinsfile shape, README accuracy. High effort."
- `tester` (Opus): "Run the full local flow: `docker compose up` → wait for both services healthy → trigger seed pipeline → confirm SonarQube analysis appears. Surface any flake."

**Phase 5 — Polish:** PR `rebuild/v1` → `main`, capture screenshots of Jenkins job + SonarQube dashboard, ask user before merging.

---

## Goal

Rebuild this repo from a misnamed static-HTML gym-site template into what the
**name actually promises**: a working **Jenkins + Docker + SonarQube** demo
showing CI/CD with quality gates.

**What's there now (do not keep):** static Bootstrap "Neogym" gym landing page
HTML/CSS/JS. Nothing to do with Jenkins, Docker, or SonarQube. The repo name was
clearly the assignment topic; the content was apparently unrelated.

**What this should become (target):** A self-contained, run-locally-with-`docker compose up`
demo of:
- A small **app** (Python or Node, user picks)
- A **Jenkins** instance configured-as-code (JCasC) with one seed pipeline
- A **SonarQube** instance with a quality gate
- A **Jenkinsfile** that: lints → tests → runs Sonar analysis → builds image → publishes if quality gate passes
- A README that says *"clone, `docker compose up`, open localhost:8080, see the pipeline run"*

**Sells:** Jenkins, CI/CD, SonarQube, Docker, Code Quality, DevOps.

## Business decisions to ask the user about

These are load-bearing — surface them **before any code is written**:

- **Keep "Jenkins-Docker-Sonarqube" as the repo name?** It's accurate to the rebuild, so probably yes. Confirm.
- **Demo app stack** — recommend Python Flask (matches the user's Python skill, simple). Alternatives: Node/Express. Could be the **same app** as `DevOpsCourse` for narrative consistency, or a slightly different one to avoid duplication.
- **Whether to wipe the static gym HTML entirely** — recommend yes (it's not relevant). Confirm.
- **SonarQube quality gate strictness** — recommend the default "Sonar way" gate for v1; bespoke gates are out of scope.
- **Whether to publish the Jenkins seed pipeline as Job DSL Groovy or pipeline-from-SCM** — recommend pipeline-from-SCM (simpler, more modern).
- **Whether to include screenshots of the Jenkins UI + SonarQube dashboard** in the README — recommend yes (this is what sells the repo).

## Scope (must-haves)

1. **Clean rebuild** on a `rebuild/v1` branch; merge to `main` only at the end.
2. **Demo app** (small) with deliberate, low-severity SonarQube findings so the dashboard isn't empty.
3. **`docker-compose.yml`** — Jenkins + SonarQube + Postgres, healthchecks, named volumes for persistence.
4. **JCasC config** — `jenkins/jenkins.yaml` declaring system config + one seed job pointing at the Jenkinsfile in this repo.
5. **`Jenkinsfile`** — declarative pipeline with stages: Checkout → Lint → Test → SonarQube Analysis → Quality Gate → Build Image → (optional) Publish.
6. **`sonar-project.properties`** — project key, sources, exclusions, language settings.
7. **README** — what each service does, how to run, default credentials, screenshots, troubleshooting.

## Production hygiene (must apply, not optional)

Inherits the master plan's "Production hygiene checklist." Repo-specific application:

- **No real secrets in compose or Jenkins config.** Demo credentials clearly marked `demo-only`. Anything resembling a real key is gitignored. README points future users at proper credential providers.
- **Pydantic input validation on the demo Flask app's routes.** Bad input → 400 JSON, never a stack trace. (Same pattern as `DevOpsCourse`.)
- **Global Flask error handler returning generic JSON.** No tracebacks in HTTP responses.
- **Sonar quality gate enforcement is the safety net.** The Jenkinsfile's "Quality Gate" stage uses `waitForQualityGate abortPipeline: true`. If Sonar finds critical issues, the pipeline fails — that's the demo.

## Out of scope

- No external CI (GitHub Actions stays out — point of this repo is self-hosted Jenkins)
- No production deployment
- No SonarQube enterprise features
- No multi-tenant / team config
- No long-running cluster install (kind / k8s) — docker-compose only

## Tech stack

Default (subject to user):
- **App:** Python 3.12 + Flask (or Node 20)
- **Jenkins:** `jenkins/jenkins:lts` + JCasC plugin set
- **SonarQube:** `sonarqube:lts-community`
- **Postgres:** `postgres:16-alpine` (Sonar backend)
- **Sonar Scanner:** Sonar Scanner CLI
- **Linting:** `actionlint` for any incidental workflows; `ruff` (Python) or `eslint` (Node)
- **Testing:** `pytest --cov` (Python) or `jest --coverage` (Node)

## File tree (after rebuild)

```
Jenkins-Docker-Sonarqube/
  README.md
  PLAN.md
  LICENSE                       ← MIT (already exists; keep)
  .gitignore
  docker-compose.yml
  jenkins/
    Dockerfile                  ← extends jenkins/jenkins:lts, installs plugins, embeds JCasC + seed config
    plugins.txt
    jenkins.yaml                ← JCasC system config + seed job
    casc.yaml                   ← optional split
  sonar/
    Dockerfile                  ← optional; usually plain image
  app/                          ← demo app (whatever stack chosen)
    main.py
    routes.py
    healthcheck.py
  tests/
    test_main.py
  Jenkinsfile                   ← pipeline used by the seed job
  sonar-project.properties
  Dockerfile                    ← demo app multi-stage build
  .dockerignore
  scripts/
    wait-for-it.sh
    bootstrap.sh                ← optional; downloads scanner CLI etc.
  docs/
    screenshots/
      jenkins-pipeline.png
      sonarqube-dashboard.png
    diagrams/
      flow.png                  ← request flow: developer → Jenkins → SonarQube → image
```

## Step-by-step build

### 1. Branch + clean

```bash
git checkout -b rebuild/v1
git rm -rf contact.html index.html trainer.html why.html css/ images/ js/
```

(Keep `LICENSE`. Add `README.md` fresh.)

### 2. Demo app

Same Flask skeleton as `DevOpsCourse` (or a sibling) with intentional low-severity Sonar findings (e.g. an unused variable, a long function, a print-debug line) so the dashboard has signal.

### 3. `docker-compose.yml`

Three services: `jenkins`, `sonarqube`, `postgres`. Healthchecks on each, named volumes (`jenkins_home`, `sonarqube_data`, `sonarqube_extensions`, `pg_data`). Jenkins exposes 8080, SonarQube exposes 9000.

### 4. Jenkins as code

`jenkins/Dockerfile`:
- `FROM jenkins/jenkins:lts`
- Install plugins from `plugins.txt` (`configuration-as-code`, `job-dsl`, `workflow-aggregator`, `git`, `docker-workflow`, `sonar`, `pipeline-stage-view`)
- `COPY jenkins.yaml /var/jenkins_home/casc_configs/`
- `ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml`

`jenkins/jenkins.yaml` (JCasC):
- System message
- Disable setup wizard
- Credentials (use Docker secrets in real life; placeholder for demo)
- Sonar server config pointing at `http://sonarqube:9000`
- Seed `pipelineJob('demo')` defining `pipeline.git.scm` from this repo + `Jenkinsfile`

### 5. `Jenkinsfile`

```groovy
pipeline {
  agent any
  options { timestamps() }
  environment { SONAR_HOST_URL = 'http://sonarqube:9000' }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Lint')     { steps { sh 'ruff check .' } }
    stage('Test')     { steps { sh 'pytest --cov=app --cov-report=xml' } }
    stage('SonarQube Analysis') {
      steps { withSonarQubeEnv('sonarqube') { sh 'sonar-scanner' } }
    }
    stage('Quality Gate') {
      steps { timeout(time: 5, unit: 'MINUTES') { waitForQualityGate abortPipeline: true } }
    }
    stage('Build Image') { steps { sh 'docker build -t demo:${BUILD_NUMBER} .' } }
  }
}
```

### 6. `sonar-project.properties`

```properties
sonar.projectKey=jenkins-docker-sonarqube
sonar.projectName=Jenkins Docker Sonarqube Demo
sonar.sources=app
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.exclusions=**/__pycache__/**
```

### 7. App Dockerfile + `.dockerignore`

Multi-stage, non-root, healthcheck. Same shape as `DevOpsCourse`.

### 8. README

1. Title — *Jenkins-Docker-Sonarqube — Self-hosted CI/CD demo with quality gates*
2. Demo — `docs/screenshots/jenkins-pipeline.png` + `sonarqube-dashboard.png`
3. Flow diagram
4. What it shows — Jenkins JCasC, SonarQube quality gate enforcement, Docker image build, all reproducible via docker-compose
5. Skills demonstrated — Jenkins, CI/CD, SonarQube, Code Quality, Docker, Docker Compose, JCasC, Pipeline-as-Code
6. Quick start: `docker compose up -d && open http://localhost:8080`
7. Default credentials (clearly marked as demo-only)
8. Troubleshooting (port conflicts, slow first boot)
9. License — MIT

### 9. Polish + merge

PR `rebuild/v1` → `main`. Capture screenshots after a green pipeline run. Topics: `jenkins`, `sonarqube`, `cicd`, `docker`, `code-quality`, `pipeline-as-code`, `jcasc`. Ask user before merging.

## Verification

- [ ] Old static gym HTML/CSS/JS removed
- [ ] Fresh clone → `docker compose up -d` brings both services healthy within 5 minutes
- [ ] Default Jenkins login works (or doc'd)
- [ ] Seed pipeline runs end-to-end, all stages green
- [ ] SonarQube shows the project with at least one finding (intentional)
- [ ] Quality gate enforcement works (verified by pushing a deliberately bad commit and watching the gate fail)
- [ ] README has both screenshots + flow diagram
- [ ] No SAP-internal references; no `~/.claude/` references
- [ ] Topics + description set
- [ ] Default branch description aligned with the rebuild
- [ ] Demo Flask app: bad payload returns 400 JSON, not an HTML stack trace
- [ ] Demo credentials clearly marked `demo-only` in README and compose

## Stretch (defer)

- Cosign signing of pushed images
- Multi-pipeline seed (one Python, one Node) showing parameterised Job DSL
- Slack notification on quality gate failure
- Helm chart that deploys the same Jenkins+Sonar+app trio into kind
