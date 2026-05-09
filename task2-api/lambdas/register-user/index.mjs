// POST /register — регистрирует участника на мероприятие.
//
// Дополнительно атомарно увеличивает счётчик `registrations` в записи мероприятия,
// чтобы GET /stats работал быстро без сканирования таблицы регистраций.

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "node:crypto";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const EVENTS_TABLE = process.env.EVENTS_TABLE;
const REGISTRATIONS_TABLE = process.env.REGISTRATIONS_TABLE;

const CORS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const respond = (statusCode, body) => ({
  statusCode,
  headers: CORS,
  body: JSON.stringify(body),
});

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const handler = async (event) => {
  try {
    let body = {};
    try {
      body = JSON.parse(event.body || "{}");
    } catch {
      return respond(400, { message: "body должен быть валидным JSON" });
    }

    const eventId = (body.eventId || "").toString().trim();
    const userName = (body.userName || "").toString().trim();
    const email = (body.email || "").toString().trim();

    if (!eventId || !userName || !email) {
      return respond(400, {
        message: "eventId, userName и email обязательны",
      });
    }
    if (!EMAIL_RE.test(email)) {
      return respond(400, { message: "email невалидный" });
    }

    // проверка существования мероприятия
    const found = await ddb.send(
      new GetCommand({ TableName: EVENTS_TABLE, Key: { id: eventId } }),
    );
    if (!found.Item) {
      return respond(404, { message: "event not found" });
    }

    const registration = {
      id: randomUUID(),
      eventId,
      userName,
      email,
      registeredAt: new Date().toISOString(),
    };

    await ddb.send(
      new PutCommand({ TableName: REGISTRATIONS_TABLE, Item: registration }),
    );

    // атомарный инкремент счётчика регистраций на мероприятии
    await ddb.send(
      new UpdateCommand({
        TableName: EVENTS_TABLE,
        Key: { id: eventId },
        UpdateExpression: "ADD registrations :one",
        ExpressionAttributeValues: { ":one": 1 },
      }),
    );

    return respond(201, registration);
  } catch (err) {
    console.error("register-user error:", err);
    return respond(500, { message: "internal error", error: err.message });
  }
};
