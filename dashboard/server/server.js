/* server.js — Relay WebSocket tra il MASTER (ESP32) e la dashboard (browser).
 *
 * Serve sia la pagina statica (HTTP) sia il WebSocket sulla STESSA porta: basta
 * un solo indirizzo. La pagina si connette al WS dello stesso host, quindi non
 * c'e' nessun indirizzo da scrivere a mano nel frontend.
 *
 * Ruoli (il client si dichiara col primo messaggio {"t":"hello","role":...}):
 *   - "device" = ESP32 master
 *   - "ui"     = browser/dashboard
 *
 * Flusso messaggi (JSON):
 *   device -> server -> tutte le ui:
 *     {"t":"status","paired":bool,"slave_id":n}
 *     {"t":"event","dir":"rx"|"tx","msg":"REQ"|"SET"|"OK"|"REQ_PRESENCE"|
 *                                         "PRESENCE_YES"|"PRESENCE_NO"|"ABORT"}
 *     {"t":"presence","present":bool}
 *   ui -> server -> tutti i device:
 *     {"t":"cmd","cmd":"request_presence"|"abort"}
 *   server -> ui (informativi):
 *     {"t":"device","online":bool}     // il master e' connesso al server?
 *     piu' lo stato/presenza in cache appena la ui si connette.
 */
'use strict';

const http = require('http');
const fs   = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT       = process.env.PORT || 8080;
const PUBLIC_DIR = path.join(__dirname, '..');   // cartella dashboard/ (index.html, ...)

/* ---------------------- server HTTP per i file statici --------------------- */
const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.css' : 'text/css; charset=utf-8',
    '.js'  : 'text/javascript; charset=utf-8',
    '.svg' : 'image/svg+xml',
    '.ico' : 'image/x-icon',
};

const httpServer = http.createServer((req, res) => {
    let urlPath = decodeURIComponent(req.url.split('?')[0]);
    if (urlPath === '/') urlPath = '/index.html';

    // niente path traversal: risolvo dentro PUBLIC_DIR
    const filePath = path.join(PUBLIC_DIR, path.normalize(urlPath));
    if (!filePath.startsWith(PUBLIC_DIR)) { res.writeHead(403); return res.end('forbidden'); }

    fs.readFile(filePath, (err, data) => {
        if (err) { res.writeHead(404); return res.end('not found'); }
        res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath)] || 'application/octet-stream' });
        res.end(data);
    });
});

/* ------------------------------- WebSocket --------------------------------- */
const wss = new WebSocketServer({ server: httpServer });

const devices = new Set();   // ESP32 master
const uis      = new Set();  // browser

// ultimo stato noto: serve a popolare subito una ui appena connessa
let lastStatus   = { t: 'status', paired: false, slave_id: -1 };
let lastPresence = { t: 'presence', present: null };

function send(ws, obj) {
    if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}
function broadcast(set, obj) { for (const ws of set) send(ws, obj); }

wss.on('connection', (ws) => {
    ws.role = null;

    ws.on('message', (raw) => {
        let m;
        try { m = JSON.parse(raw.toString()); } catch { return; }

        // primo messaggio: dichiarazione del ruolo
        if (m.t === 'hello') {
            ws.role = (m.role === 'device') ? 'device' : 'ui';
            if (ws.role === 'device') {
                devices.add(ws);
                broadcast(uis, { t: 'device', online: true });
            } else {
                uis.add(ws);
                // popola subito la nuova dashboard con lo stato corrente
                send(ws, { t: 'device', online: devices.size > 0 });
                send(ws, lastStatus);
                if (lastPresence.present !== null) send(ws, lastPresence);
            }
            return;
        }

        if (ws.role === 'device') {
            // dal master verso tutte le dashboard; aggiorno la cache
            if (m.t === 'status')   lastStatus = m;
            if (m.t === 'presence') lastPresence = m;
            broadcast(uis, m);
        } else if (ws.role === 'ui') {
            // dalla dashboard verso il master
            if (m.t === 'cmd') broadcast(devices, m);
        }
    });

    ws.on('close', () => {
        devices.delete(ws);
        uis.delete(ws);
        if (ws.role === 'device') broadcast(uis, { t: 'device', online: devices.size > 0 });
    });

    ws.on('error', () => {});
});

httpServer.listen(PORT, () => {
    console.log(`[server] HTTP + WebSocket su http://0.0.0.0:${PORT}`);
    console.log(`[server] dashboard: apri http://<questo-host>:${PORT}/`);
});
