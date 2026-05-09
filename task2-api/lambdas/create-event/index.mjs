// POST /event — создаёт мероприятие в DynamoDB.

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "node:crypto";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const EVENTS_TABLE = process.env.EVENTS_TABLE;

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

export const handler = async (event) => {
  try {
    let body = {};
    try {
      body = JSON.parse(event.body || "{}");
    } catch {
      return respond(400, { message: "body должен быть валидным JSON" });
    }

    const name = (body.name || "").toString().trim();
    const date = (body.date || "").toString().trim();
    const description = (body.description || "").toString().trim();

    if (!name || !date) {
      return respond(400, { message: "name и date обязательны" });
    }
    if (name.length > 100) {
      return respond(400, { message: "name слишком длинное (max 100)" });
    }

    const item = {
      id: randomUUID(),
      name,
      date,
      description,
      registrations: 0,
      createdAt: new Date().toISOString(),
    };

    await ddb.send(new PutCommand({ TableName: EVENTS_TABLE, Item: item }));

    return respond(201, item);
  } catch (err) {
    console.error("create-event error:", err);
    return respond(500, { message: "internal error", error: err.message });
  }
};
