from fastapi.testclient import TestClient


def test_healthz(client: TestClient) -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_version(client: TestClient) -> None:
    assert "version" in client.get("/version").json()


def test_create_link_and_follow(client: TestClient) -> None:
    created = client.post("/api/links", json={"target_url": "https://example.com/page"})
    assert created.status_code == 201
    body = created.json()
    assert len(body["code"]) == 7
    assert body["visits"] == 0

    redirect = client.get(f"/{body['code']}", follow_redirects=False)
    assert redirect.status_code == 307
    assert redirect.headers["location"] == "https://example.com/page"

    stats = client.get(f"/api/links/{body['code']}")
    assert stats.json()["visits"] == 1


def test_unknown_code_returns_404(client: TestClient) -> None:
    assert client.get("/api/links/missing", follow_redirects=False).status_code == 404
    assert client.get("/missing", follow_redirects=False).status_code == 404


def test_invalid_url_is_rejected(client: TestClient) -> None:
    assert client.post("/api/links", json={"target_url": "not-a-url"}).status_code == 422


def test_metrics_endpoint_exposes_prometheus_data(client: TestClient) -> None:
    client.get("/healthz")  # generate at least one measured request
    response = client.get("/metrics")
    assert response.status_code == 200
    body = response.text
    assert "http_requests_total" in body
    assert "http_request_duration_seconds" in body
