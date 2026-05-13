"""Flask-сервис со списком мероприятий и health-check.

Эндпоинты:
    GET /events  — список мероприятий + поле `served_by` с hostname контейнера
                   (чтобы видно было, какой инстанс ответил)
    GET /health  — 200 OK, тривиальная проверка живости

Источник данных управляется переменной EVENTS_SOURCE:
    mock       — захардкоженный список (по умолчанию, не нужен AWS)
    dynamodb   — читает таблицу Events из DynamoDB (нужны AWS-креды)
"""

import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)

HOST = socket.gethostname()
EVENTS_SOURCE = os.getenv("EVENTS_SOURCE", "mock").lower()
DDB_TABLE = os.getenv("DDB_EVENTS_TABLE", "Events")
AWS_REGION = os.getenv("AWS_REGION", "eu-north-1")

MOCK_EVENTS = [
    {
        "id": "demo-1",
        "name": "Tech Meetup",
        "date": "2026-06-15",
        "registrations": 12,
    },
    {
        "id": "demo-2",
        "name": "Design Talk",
        "date": "2026-07-01",
        "registrations": 7,
    },
    {
        "id": "demo-3",
        "name": "AWS Workshop",
        "date": "2026-07-20",
        "registrations": 23,
    },
]


def _fetch_from_dynamodb():
    """Сканит таблицу Events и приводит к плоским dict-ам."""
    import boto3  # импорт здесь, чтобы mock-режим работал без boto3 в окружении

    ddb = boto3.client("dynamodb", region_name=AWS_REGION)
    resp = ddb.scan(TableName=DDB_TABLE)
    items = []
    for raw in resp.get("Items", []):
        items.append(
            {
                "id": raw.get("id", {}).get("S"),
                "name": raw.get("name", {}).get("S"),
                "date": raw.get("date", {}).get("S"),
                "registrations": int(raw.get("registrations", {}).get("N", "0")),
            }
        )
    return items


@app.route("/events", methods=["GET"])
def events():
    if EVENTS_SOURCE == "dynamodb":
        try:
            items = _fetch_from_dynamodb()
            source = "dynamodb"
        except Exception as exc:  # noqa: BLE001 — отдадим текст ошибки наружу
            return (
                jsonify(
                    {
                        "served_by": HOST,
                        "source": "dynamodb",
                        "error": str(exc),
                        "items": [],
                    }
                ),
                502,
            )
    else:
        items = MOCK_EVENTS
        source = "mock"

    return jsonify({"served_by": HOST, "source": source, "items": items})


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "served_by": HOST}), 200


if __name__ == "__main__":
    # dev-режим — для прода используется gunicorn (см. Dockerfile)
    port = int(os.getenv("FLASK_PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)
