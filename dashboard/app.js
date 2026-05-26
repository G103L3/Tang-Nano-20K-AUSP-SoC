/* app.js — dashboard del master EFES.
 * Si connette al WebSocket dello STESSO host che serve la pagina (nessun
 * indirizzo da scrivere). Mostra stato aggancio, presenza (lampadina) e il
 * traffico in chiaro (etichette leggibili invece dei bit). */
'use strict';

/* nome leggibile + tipo "chip" per ogni messaggio del protocollo */
const MSG = {
  REQ:          { label: 'Richiesta registrazione', chip: '' },
  SET:          { label: 'Assegnazione ID (id=1)',  chip: '' },
  OK:           { label: 'Conferma OK',             chip: '' },
  REQ_PRESENCE: { label: 'Richiesta presenza',      chip: '' },
  PRESENCE_YES: { label: 'Presenza: SÌ',            chip: 'yes' },
  PRESENCE_NO:  { label: 'Presenza: NO',            chip: 'no'  },
  ABORT:        { label: 'Abort',                   chip: '' },
};

const $ = (id) => document.getElementById(id);
const el = {
  serverDot: $('serverDot'), serverText: $('serverText'),
  deviceDot: $('deviceDot'), deviceText: $('deviceText'),
  pairBadge: $('pairBadge'), pairDetail: $('pairDetail'),
  bulb: $('bulb'), presenceText: $('presenceText'),
  askBtn: $('askBtn'), clearBtn: $('clearBtn'), log: $('log'),
};

/* INDIRIZZO DEL RELAY.
 * - Lascia '' se la pagina e' servita dallo STESSO server del WebSocket
 *   (es. il server Node locale): usa automaticamente lo stesso host.
 * - Se la pagina sta su un host statico (es. htdocs) e il relay e' altrove
 *   (es. Cloudflare Worker), metti qui l'URL completo:
 *       const RELAY_URL = 'wss://efes-relay.TUO-ACCOUNT.workers.dev';
 */
const RELAY_URL = 'wss://efes-relay.giuntagioele0.workers.dev';

let ws = null;
let reconnectTimer = null;

function wsURL() {
  if (RELAY_URL) return RELAY_URL;
  const proto = (location.protocol === 'https:') ? 'wss' : 'ws';
  return `${proto}://${location.host}`;
}

function connect() {
  ws = new WebSocket(wsURL());

  ws.onopen = () => {
    setServer(true);
    ws.send(JSON.stringify({ t: 'hello', role: 'ui' }));
  };
  ws.onclose = () => {
    setServer(false);
    setDevice(false);
    // riprova fra 2 s
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connect, 2000);
  };
  ws.onerror = () => ws.close();
  ws.onmessage = (e) => {
    let m; try { m = JSON.parse(e.data); } catch { return; }
    handle(m);
  };
}

function handle(m) {
  switch (m.t) {
    case 'device':   setDevice(!!m.online); break;
    case 'status':   setPairing(!!m.paired, m.slave_id); break;
    case 'presence': setPresence(m.present); break;
    case 'event':    addLog(m.dir, m.msg); break;
  }
}

/* ---------- render ---------- */
function setServer(on) {
  el.serverDot.className = 'dot ' + (on ? 'dot--on' : 'dot--off');
  el.serverText.textContent = on ? 'Server: connesso' : 'Server: disconnesso';
}

function setDevice(on) {
  el.deviceDot.className = 'dot ' + (on ? 'dot--on' : 'dot--off');
  el.deviceText.textContent = on ? 'Master connesso al server' : 'Master non connesso al server';
  // il bottone ha senso solo se il master e' online
  el.askBtn.disabled = !on;
}

function setPairing(paired, slaveId) {
  if (paired) {
    el.pairBadge.className = 'badge badge--on';
    el.pairBadge.textContent = 'Agganciato';
    el.pairDetail.textContent = `Slave registrato (id ${slaveId}).`;
  } else {
    el.pairBadge.className = 'badge badge--off';
    el.pairBadge.textContent = 'Non agganciato';
    el.pairDetail.textContent = 'Nessuno slave registrato.';
  }
}

function setPresence(present) {
  if (present === true) {
    el.bulb.className = 'bulb is-on';
    el.presenceText.className = 'presence-text is-on';
    el.presenceText.textContent = 'Presenza rilevata';
  } else if (present === false) {
    el.bulb.className = 'bulb is-off';
    el.presenceText.className = 'presence-text is-off';
    el.presenceText.textContent = 'Nessuna presenza';
  } else {
    el.bulb.className = 'bulb is-unknown';
    el.presenceText.className = 'presence-text';
    el.presenceText.textContent = 'In attesa…';
  }
}

function addLog(dir, msg) {
  const info = MSG[msg] || { label: msg, chip: '' };
  const isRx = (dir === 'rx');

  const li = document.createElement('li');
  const time = new Date().toLocaleTimeString('it-IT');
  const chipClass = info.chip ? `chip chip--${info.chip}` : 'chip';

  li.innerHTML =
    `<span class="arrow arrow--${isRx ? 'rx' : 'tx'}">${isRx ? '↓' : '↑'}</span>` +
    `<span class="dir">${isRx ? 'Ricevuto dallo slave' : 'Inviato allo slave'}</span>` +
    `<span class="${chipClass}">${info.label}</span>` +
    `<span class="time">${time}</span>`;

  // togli il placeholder "vuoto" se presente
  const empty = el.log.querySelector('.empty');
  if (empty) empty.remove();

  el.log.prepend(li);
  while (el.log.children.length > 50) el.log.lastChild.remove();
}

function setEmptyLog() {
  el.log.innerHTML = '<li class="empty">Nessun traffico ancora.</li>';
}

/* ---------- azioni utente ---------- */
el.askBtn.addEventListener('click', () => {
  if (ws && ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify({ t: 'cmd', cmd: 'request_presence' }));
  }
});
el.clearBtn.addEventListener('click', setEmptyLog);

/* ---------- avvio ---------- */
setEmptyLog();
connect();
