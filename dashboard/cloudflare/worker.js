/* worker.js — Relay WebSocket su Cloudflare Workers + Durable Object.
 *
 * Stessa logica di ../server/server.js, ma serverless: gira su Cloudflare senza
 * una macchina da tenere accesa. NON serve i file statici: la pagina
 * (index.html/style.css/app.js) la metti su htdocs e punti app.js a questo
 * Worker via RELAY_URL = "wss://<nome>.<account>.workers.dev".
 *
 * Tutte le connessioni vanno in un'unica istanza del Durable Object ("global"),
 * che fa da hub: ruoli device/ui, cache stato, broadcast.
 */

export default {
  async fetch(request, env) {
    // solo richieste di upgrade a WebSocket; le altre danno una pagina di stato
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('EFES relay attivo. Connettiti via WebSocket.', {
        status: 200,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }
    const id   = env.RELAY.idFromName('global');   // singola istanza condivisa
    const stub = env.RELAY.get(id);
    return stub.fetch(request);
  },
};

export class Relay {
  constructor(state, env) {
    this.uis     = new Set();   // browser
    this.devices = new Set();   // ESP32 master
    this.lastStatus   = { t: 'status', paired: false, slave_id: -1 };
    this.lastPresence = { t: 'presence', present: null };
  }

  async fetch(request) {
    const pair = new WebSocketPair();
    const client = pair[0], server = pair[1];
    server.accept();
    server.__role = null;
    server.addEventListener('message', (evt) => this.onMessage(server, evt.data));
    server.addEventListener('close',   () => this.onClose(server));
    server.addEventListener('error',   () => this.onClose(server));
    return new Response(null, { status: 101, webSocket: client });
  }

  send(ws, obj)        { try { ws.send(JSON.stringify(obj)); } catch {} }
  broadcast(set, obj)  { for (const ws of set) this.send(ws, obj); }

  onMessage(ws, raw) {
    let m;
    try { m = JSON.parse(raw); } catch { return; }

    if (m.t === 'hello') {
      ws.__role = (m.role === 'device') ? 'device' : 'ui';
      if (ws.__role === 'device') {
        this.devices.add(ws);
        this.broadcast(this.uis, { t: 'device', online: true });
      } else {
        this.uis.add(ws);
        this.send(ws, { t: 'device', online: this.devices.size > 0 });
        this.send(ws, this.lastStatus);
        if (this.lastPresence.present !== null) this.send(ws, this.lastPresence);
      }
      return;
    }

    if (ws.__role === 'device') {
      if (m.t === 'status')   this.lastStatus = m;
      if (m.t === 'presence') this.lastPresence = m;
      this.broadcast(this.uis, m);
    } else if (ws.__role === 'ui') {
      if (m.t === 'cmd') this.broadcast(this.devices, m);
    }
  }

  onClose(ws) {
    this.devices.delete(ws);
    this.uis.delete(ws);
    if (ws.__role === 'device') {
      this.broadcast(this.uis, { t: 'device', online: this.devices.size > 0 });
    }
  }
}
