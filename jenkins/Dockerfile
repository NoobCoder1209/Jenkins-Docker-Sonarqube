FROM jenkins/jenkins:lts

USER root

# Docker CLI (the daemon comes from the host via /var/run/docker.sock bind-mount)
# and curl for the SonarQube health/webhook calls inside Jenkinsfile if needed.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        docker.io \
        curl \
 && rm -rf /var/lib/apt/lists/*

# Python toolchain so the Jenkinsfile can run pytest/ruff directly on the controller.
# (Single-node demo — no agent pool to dispatch to.)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
 && rm -rf /var/lib/apt/lists/*

USER jenkins

# Plugins. jenkins-plugin-cli (bundled in the LTS image) resolves against the
# core's update-center metadata, so unpinned versions stay compatible.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# JCasC config. Lives under /usr/share/jenkins/ref/ (NOT /var/jenkins_home/...)
# because the named volume mounted at /var/jenkins_home would shadow files
# baked into that directory on second boot.
COPY jenkins.yaml /usr/share/jenkins/ref/casc_configs/jenkins.yaml
