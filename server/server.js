const { WebSocketServer, WebSocket } = require("ws");
const { randomUUID } = require("crypto");

const port = Number(process.env.PORT || 8080);
const wss = new WebSocketServer({ port });
const clients = new Map();

function send(ws, message) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(message));
}

function broadcast(room, sender, message) {
  for (const [ws, client] of clients) {
    if (ws !== sender && client.room === room) send(ws, message);
  }
}

wss.on("connection", (ws) => {
  const client = { id: randomUUID(), room: "" };
  clients.set(ws, client);
  send(ws, { type: "welcome", id: client.id });

  ws.on("message", (raw) => {
	if (raw.length > 4096) return;
    let message;
    try { message = JSON.parse(raw.toString()); } catch { return; }
    if (message.type === "join") {
      client.room = String(message.room || "THATVRKIDD").replace(/[^A-Z0-9]/gi, "").slice(0, 12);
      return;
    }
    if (!client.room) return;
	if (message.type === "pose" && [message.head, message.left, message.right].every(v => Array.isArray(v) && v.length === 7)) {
      broadcast(client.room, ws, { ...message, id: client.id });
    } else if (message.type === "tag") {
      broadcast(client.room, ws, { type: "tag", id: client.id, target: String(message.target || "") });
    } else if (message.type === "leave") {
      ws.close(1000);
    }
  });

  ws.on("close", () => {
    if (client.room) broadcast(client.room, ws, { type: "left", id: client.id });
    clients.delete(ws);
  });
});

console.log(`ThatVRKidd room server listening on ${port}`);
