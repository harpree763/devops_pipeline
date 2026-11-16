"""Demo FastAPI service for the Safe Delivery Platform.

Exposes /health, /work (synthetic latency + configurable failure rate)
and /metrics (Prometheus exposition format). Every request (except
/metrics itself) is counted and timed, and logged as a single JSON line.
"""
import json
import logging
import os
import random
import time

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

APP_VERSION = os.environ.get("APP_VERSION", "v1")
FAIL_RATE = float(os.environ.get("FAIL_RATE", "0"))

app = FastAPI(title="safe-delivery-demo-service")

logger = logging.getLogger("demo_service")
logging.basicConfig(level=logging.INFO, format="%(message)s")

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["path"],
)


@app.middleware("http")
async def metrics_and_logging_middleware(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    start = time.perf_counter()
    response = await call_next(request)
    duration = time.perf_counter() - start

    method = request.method
    path = request.url.path
    status = response.status_code

    REQUEST_COUNT.labels(method=method, path=path, status=str(status)).inc()
    REQUEST_LATENCY.labels(path=path).observe(duration)

    logger.info(
        json.dumps(
            {
                "version": APP_VERSION,
                "method": method,
                "path": path,
                "status": status,
                "duration_ms": round(duration * 1000, 3),
            }
        )
    )
    return response


@app.get("/health")
def health():
    return {"status": "ok", "version": APP_VERSION}


@app.get("/work")
def work():
    time.sleep(random.uniform(0.005, 0.030))
    if random.random() < FAIL_RATE:
        return JSONResponse(status_code=500, content={"status": "error", "version": APP_VERSION})
    return {"status": "ok", "version": APP_VERSION}


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# retrigger after trivy-action version fix
