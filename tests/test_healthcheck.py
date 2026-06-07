from app.healthcheck import healthcheck


def test_healthcheck_returns_ok():
    assert healthcheck() == {"status": "ok"}
