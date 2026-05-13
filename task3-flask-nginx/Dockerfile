FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

# 2 воркера gunicorn — достаточно для учебной нагрузки
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "app:app"]
