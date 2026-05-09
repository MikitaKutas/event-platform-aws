// GET /stats — список мероприятий со счётчиком регистраций.

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const EVENTS_TABLE = process.env.EVENTS_TABLE;

const CORS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export const handler = async () => {
  try {
    const out = await ddb.send(new ScanCommand({ TableName: EVENTS_TABLE }));
    const items = (out.Items || [])
      .map((e) => ({
        event_id: e.id,
        name: e.name,
        date: e.date,
        registrations: e.registrations ?? 0,
      }))
      .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));

    return {
      statusCode: 200,
      headers: CORS,
      body: JSON.stringify({ items }),
    };
  } catch (err) {
    console.error("get-stats error:", err);
    return {
      statusCode: 500,
      headers: CORS,
      body: JSON.stringify({ message: "internal error", error: err.message }),
    };
  }
};
