FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first so Docker can cache this layer
# independently of application code changes.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/main.py .

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
