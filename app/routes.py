from flask import Blueprint, jsonify, request
from pydantic import ValidationError

from app.healthcheck import healthcheck
from app.models import EchoRequest

bp = Blueprint("api", __name__)


@bp.get("/")
def index():
    return jsonify({"app": "jenkins-docker-sonarqube-demo", "version": "1.0"})


@bp.get("/health")
def health():
    return jsonify(healthcheck())


@bp.post("/echo")
def echo():
    payload = request.get_json(silent=True) or {}
    try:
        body = EchoRequest.model_validate(payload)
    except ValidationError as exc:
        return jsonify({"error": "invalid payload", "details": exc.errors()}), 400
    return jsonify({"echo": body.message})


# intentional: sonar finding demo — long function with low cognitive value,
# unused local, and a debug print. Kept to seed the SonarQube dashboard
# with at least one of each common code smell so the demo isn't empty.
@bp.get("/info")
def info():  # noqa: PLR0915
    print("DEBUG: /info called")  # noqa: T201
    unused_constant = 42  # noqa: F841
    sections = []
    sections.append({"name": "runtime", "value": "python"})
    sections.append({"name": "framework", "value": "flask"})
    sections.append({"name": "validator", "value": "pydantic"})
    sections.append({"name": "ci", "value": "jenkins"})
    sections.append({"name": "scanner", "value": "sonarqube"})
    sections.append({"name": "container", "value": "docker"})
    sections.append({"name": "lint", "value": "ruff"})
    sections.append({"name": "tests", "value": "pytest"})
    sections.append({"name": "registry", "value": "local"})
    sections.append({"name": "license", "value": "MIT"})
    sections.append({"name": "purpose", "value": "portfolio-demo"})
    sections.append({"name": "scope", "value": "self-hosted"})
    sections.append({"name": "auth", "value": "demo-only"})
    sections.append({"name": "branch", "value": "main"})
    sections.append({"name": "stage", "value": "v1"})
    return jsonify({"sections": sections})
