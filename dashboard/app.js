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
  memList: $('memList'), memLoadBtn: $('memLoadBtn'), memClearBtn: $('memClearBtn'),
  memStats: $('memStats'),
  noteInput: $('noteInput'), noteBtn: $('noteBtn'),
  setName: $('setName'), setAuto: $('setAuto'), setTries: $('setTries'),
  setReloadBtn: $('setReloadBtn'), setSaveBtn: $('setSaveBtn'),
  setFeedback: $('setFeedback'),
};

let memCount = 0;
let memLastAt = 0;
let savingSettings = false;

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
    case 'flashlog': renderMem(m.recs || []); break;
    case 'settings': fillSettings(m); break;
    case 'flashok':  /* opzionale: feedback */ break;
  }
}

function sendCmd(obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
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
  el.memLoadBtn.disabled  = !on;
  el.memClearBtn.disabled = !on;
  el.noteBtn.disabled     = !on;
  el.setReloadBtn.disabled = !on;
  el.setSaveBtn.disabled   = !on;
  if (on) {
    sendCmd({ t: 'cmd', cmd: 'flash_load' });
    sendCmd({ t: 'cmd', cmd: 'settings_get' });
  }
}

function decodeEvt(txt) {
  switch (txt) {
    case 'S:REQ':   return { label: 'Slave: richiesta ID',     dir: 'Es' };
    case 'M:SET1':  return { label: 'Master: assegna ID = 1',  dir: 'Em' };
    case 'S:OK1':   return { label: 'Slave: OK (id = 1)',      dir: 'Es' };
    case 'M:PRES?': return { label: 'Master: chiede presenza', dir: 'Em' };
    case 'S:PRES1': return { label: 'Slave: presenza SÌ',      dir: 'Es' };
    case 'S:PRES0': return { label: 'Slave: presenza NO',      dir: 'Es' };
    case 'M:ABORT': return { label: 'Master: ABORT',           dir: 'Em' };
    default:
      if (txt && txt.startsWith('J:')) return { label: 'Flash JEDEC: ' + txt.slice(2), dir: 'Em' };
      return { label: txt || '?', dir: (txt && txt.startsWith('M:')) ? 'Em' : 'Es' };
  }
}

function recTypeLabel(rec) {
  switch (rec.type) {
    case 'B': return { label: 'Boot',                     cls: 'recchip--B' };
    case 'R': return { label: 'Registrato id=' + rec.val, cls: 'recchip--R' };
    case 'P': return rec.val
      ? { label: 'Presenza: SÌ', cls: 'recchip--Pyes' }
      : { label: 'Presenza: NO', cls: 'recchip--Pno'  };
    case 'N': return { label: 'Nota',                     cls: 'recchip--N' };
    case 'E': {
      const e = decodeEvt(rec.text || '');
      return { label: e.label, cls: 'recchip--' + e.dir };
    }
    default : return { label: rec.type || '?',            cls: '' };
  }
}

function formatTSec(t) {
  t = Math.max(0, Number(t) | 0);
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const s = t % 60;
  if (h) return `${h}h ${m}m ${s}s`;
  if (m) return `${m}m ${s}s`;
  return `${s}s`;
}

function renderMem(recs) {
  el.memList.innerHTML = '';
  memCount = recs.length;
  memLastAt = Date.now();
  if (!recs.length) {
    el.memList.innerHTML = '<li class="empty">Nessun record in memoria — premi <b>Aggiungi nota</b> per scrivere il primo.</li>';
    updateMemStats();
    return;
  }
  for (const r of recs) {
    const info = recTypeLabel(r);
    const li = document.createElement('li');
    const txt = (r.text || '').toString().replace(/[^\x20-\x7E]/g, '');
    li.innerHTML =
      `<span class="seq">#${r.seq}</span>` +
      `<span class="recchip ${info.cls}">${info.label}</span>` +
      ((txt && r.type === 'N') ? `<span class="rec-text">${txt}</span>` : '') +
      `<span class="time">${formatTSec(r.t)} dal boot</span>`;
    el.memList.appendChild(li);
  }
  updateMemStats();
}

function updateMemStats() {
  if (!memLastAt) { el.memStats.textContent = ''; return; }
  const sec = Math.max(0, Math.round((Date.now() - memLastAt) / 1000));
  let when;
  if (sec < 2)        when = 'ora';
  else if (sec < 60)  when = `${sec}s fa`;
  else                when = `${Math.floor(sec / 60)}m fa`;
  el.memStats.textContent = `· ${memCount} record · aggiornato ${when}`;
}
setInterval(updateMemStats, 5000);

function fillSettings(m) {
  el.setName.value  = m.name || '';
  el.setAuto.value  = Number(m.auto)  || 0;
  el.setTries.value = Number(m.tries) || 6;
  if (savingSettings) {
    savingSettings = false;
    el.setFeedback.textContent = '· ✓ salvato';
    el.setFeedback.className   = 'stats stats--ok';
    setTimeout(() => { el.setFeedback.textContent = ''; el.setFeedback.className = 'stats'; }, 3500);
  }
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
  sendCmd({ t: 'cmd', cmd: 'request_presence' });
});
el.clearBtn.addEventListener('click', setEmptyLog);

el.memLoadBtn.addEventListener('click', () => {
  sendCmd({ t: 'cmd', cmd: 'flash_load' });
});
el.memClearBtn.addEventListener('click', () => {
  if (confirm('Svuotare la memoria? Verranno cancellati tutti i record.')) {
    sendCmd({ t: 'cmd', cmd: 'flash_clear' });
  }
});
el.noteBtn.addEventListener('click', () => {
  const txt = (el.noteInput.value || '').trim().slice(0, 8);
  if (!txt) return;
  sendCmd({ t: 'cmd', cmd: 'flash_note', text: txt });
  el.noteInput.value = '';
});
el.setReloadBtn.addEventListener('click', () => {
  sendCmd({ t: 'cmd', cmd: 'settings_get' });
});
el.setSaveBtn.addEventListener('click', () => {
  const name  = (el.setName.value  || '').trim().slice(0, 15);
  const auto_ = Math.max(0, Math.min(3600, Number(el.setAuto.value)  || 0));
  const tries = Math.max(1, Math.min(20,  Number(el.setTries.value) || 6));
  savingSettings = true;
  el.setFeedback.textContent = '· salvataggio…';
  el.setFeedback.className   = 'stats';
  sendCmd({ t: 'cmd', cmd: 'settings_set', name, auto: auto_, tries });
});

/* ---------- avvio ---------- */
setEmptyLog();
connect();
