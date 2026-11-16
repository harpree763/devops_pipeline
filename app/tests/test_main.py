"""Tests for the demo service.

Note: we deliberately do NOT importlib.reload(main) between tests.
prometheus_client registers metrics on the default REGISTRY at import
time; reloading the module re-registers the same metric names and
raises ValueError: Duplicated timeseries. Instead we monkeypatch the
module-level FAIL_RATE directly.
"""
from fastapi.testclient import TestClient

import main

client = TestClient(main.app)


def test_health_returns_200():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "version" in body


def test_work_all_succeed_when_fail_rate_zero(monkeypatch):
    monkeypatch.setattr(main, "FAIL_RATE", 0.0)
    for _ in range(20):
        response = client.get("/work")
        assert response.status_code == 200


def test_work_all_fail_when_fail_rate_one(monkeypatch):
    monkeypatch.setattr(main, "FAIL_RATE", 1.0)
    for _ in range(20):
        response = client.get("/work")
        assert response.status_code == 500


def test_metrics_contains_expected_metric_names():
    # Generate at least one sample of each metric before scraping.
    client.get("/health")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
    assert "http_request_duration_seconds" in response.text
