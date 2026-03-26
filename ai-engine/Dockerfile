FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (layer-cached)
COPY pyproject.toml ./
RUN pip install --no-cache-dir ".[dev]"

# Copy application source
COPY app/ ./app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
