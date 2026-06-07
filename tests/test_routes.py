def test_index_ok(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["app"] == "jenkins-docker-sonarqube-demo"
    assert body["version"] == "1.0"


def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_echo_happy_path(client):
    resp = client.post("/echo", json={"message": "hi"})
    assert resp.status_code == 200
    assert resp.get_json() == {"echo": "hi"}


def test_echo_rejects_empty_body(client):
    resp = client.post("/echo", json={})
    assert resp.status_code == 400
    body = resp.get_json()
    assert body["error"] == "invalid payload"
    assert "details" in body


def test_echo_rejects_too_long(client):
    resp = client.post("/echo", json={"message": "x" * 501})
    assert resp.status_code == 400


def test_echo_rejects_non_json(client):
    resp = client.post("/echo", data="not-json", content_type="text/plain")
    assert resp.status_code == 400


def test_unknown_route_returns_json_404(client):
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
    body = resp.get_json()
    assert body["status"] == 404
    assert "error" in body


def test_info_returns_sections(client):
    resp = client.get("/info")
    assert resp.status_code == 200
    body = resp.get_json()
    assert isinstance(body["sections"], list)
    assert len(body["sections"]) >= 10
