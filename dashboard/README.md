# EFES — Dashboard del master

Interfaccia web per il **master** (ESP32 + FPGA). Mostra se il master è
agganciato a uno slave, permette di chiedere la **presenza** (sensore PIR dello
slave) con un bottone, e logga in chiaro il traffico (REQ/SET/OK/presenza…)
invece dei bit grezzi. La presenza è visualizzata con una lampadina.

```
[ ESP32 master ] --WebSocket--> [ server relay (Node.js) ] <--WebSocket-- [ browser ]
```

Due modi di hostare, scegli quello che ti serve:

- **A — Tutto in locale / su una macchina con Node** (sviluppo, LAN): il server
  Node fa sia da relay sia da web server. Vedi §1.
- **B — Host statico + Cloudflare** (es. htdocs, dove NON puoi runnare Node): la
  pagina sta su htdocs, il relay è un **Cloudflare Worker**. Vedi §1-bis.

---

## 1. Modo A — server Node (locale / LAN)

Richiede Node.js ≥ 18.

```bash
cd dashboard/server
npm install        # installa "ws"
npm start          # avvia su http://0.0.0.0:8080  (PORT per cambiarla)
```

Poi apri nel browser: `http://<indirizzo-del-server>:8080/`

- In locale: `http://localhost:8080/`
- Sulla rete/host che fornisci tu: usa l'IP o il dominio di quella macchina.

In questo modo `RELAY_URL` in `app.js` resta `''` (stesso host).

---

## 1-bis. Modo B — htdocs (statico) + Cloudflare Worker

Quando l'host serve **solo file** (come htdocs) non puoi far girare Node lì.
Allora: la **pagina** sta su htdocs, il **relay** è un Cloudflare Worker.

### a) Deploy del relay (Cloudflare Worker + Durable Object)

Serve un account Cloudflare (anche free). Da `dashboard/cloudflare/`:

```bash
cd dashboard/cloudflare
npx wrangler login        # apre il browser per autorizzare
npx wrangler deploy
```

Ottieni un URL tipo `https://efes-relay.<account>.workers.dev`. Il Durable
Object con storage SQLite è incluso nel piano **free**.

### b) Carica la pagina su htdocs

Carica nel File Manager (in `htdocs/`): **`index.html`, `style.css`, `app.js`**.
Prima però apri `app.js` e imposta l'indirizzo del Worker:

```js
const RELAY_URL = 'wss://efes-relay.<account>.workers.dev';
```

Apri poi `http(s)://<tuo-htdocs>/` : la pagina si connette al Worker.

### c) ESP32 → Worker (TLS)

Il Worker è solo `https`/`wss`, quindi l'ESP32 deve usare TLS. In
[../esp32-firmware/src/web_link.cpp](../esp32-firmware/src/web_link.cpp):

```c
#define WS_HOST    "efes-relay.<account>.workers.dev"   // SENZA https://
#define WS_PORT    443
#define WS_USE_TLS 1
#define WS_PATH    "/"
```

> La libreria WebSockets su ESP32 fa il TLS in modo "insecure" (senza validare il
> certificato) quando non passi una CA: per la demo va bene e si connette a
> Cloudflare. Se il handshake fallisse, aggiorna la libreria WebSockets.

---

## 2. Configurare l'ESP32 master (vale per entrambi i modi)

Apri [../esp32-firmware/src/web_link.cpp](../esp32-firmware/src/web_link.cpp) e
imposta in cima:

```c
#define WIFI_SSID  "il-tuo-wifi"
#define WIFI_PASS  "la-password"
#define WS_HOST    "192.168.1.100"   // IP/host del server relay
#define WS_PORT    8080
#define WS_USE_TLS 0                 // 1 se il server è in https/wss
```

> ESP32 sta sul WiFi a **2.4 GHz** (niente 5 GHz). `WS_HOST` deve essere
> raggiungibile dall'ESP32 (stessa rete o host pubblico). Per `wss://`
> (`WS_USE_TLS 1`) serve un certificato lato server.

Poi compila e flasha:

```bash
cd esp32-firmware
pio run -t upload
pio device monitor      # per vedere i log WiFi/WebSocket
```

## 3. Uso

- **Stato aggancio**: verde "Agganciato (id 1)" quando lo slave si è registrato.
- **Master connesso al server**: il pallino e l'abilitazione del bottone
  dipendono dalla connessione WebSocket dell'ESP32.
- **Chiedi presenza**: invia `REQ_PRESENCE` al master → allo slave → la risposta
  (`Presenza: SÌ/NO`) accende/spegne la lampadina.
- **Traffico**: ogni messaggio inviato/ricevuto compare con etichetta leggibile,
  freccia (↑ inviato / ↓ ricevuto) e orario.

## Protocollo WebSocket (JSON)

Per chi volesse reimplementare il server o estendere la dashboard.

Il client si dichiara col primo messaggio:
```json
{"t":"hello","role":"device"}   // ESP32
{"t":"hello","role":"ui"}       // browser
```

device → (relay) → ui:
```json
{"t":"status","paired":true,"slave_id":1}
{"t":"event","dir":"rx","msg":"PRESENCE_YES"}   // dir: "rx"|"tx"
{"t":"presence","present":true}
```

ui → (relay) → device:
```json
{"t":"cmd","cmd":"request_presence"}
{"t":"cmd","cmd":"abort"}
```

server → ui (informativo):
```json
{"t":"device","online":true}    // il master è connesso al relay?
```

`msg` può essere: `REQ`, `SET`, `OK`, `REQ_PRESENCE`, `PRESENCE_YES`,
`PRESENCE_NO`, `ABORT`.
