# BookStack Installer — Phonk Edition 🎵

A fully automated BookStack + MariaDB Docker installer wrapped in a phonk demoscene experience.

**Installer by Ferit — for WOOK!**

---

## What it does

1. **Checks prerequisites** — Docker, RAM, CPU, disk space (sequentially, with flair)
2. **Phonk splash screen** — with embedded music, VHS effects, plasma background, rotating 3D cube
3. **Live install stream** — Docker image pulls, container startup, all streamed into the monitor on screen
4. **Detects when BookStack is ready** — automatically shows an **OPEN BOOKSTACK** button when the app responds
5. **One click to open** — launches BookStack in your browser

---

## Requirements

- Windows 10/11
- PowerShell 5.1+ (built-in)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — installed and running
- A screen (bigger = better, obviously)

---

## Quick Start

1. Make sure **Docker Desktop is running**
2. Double-click **`START.bat`**
3. Browser opens automatically at `http://127.0.0.1:8888/demoscene.html`
4. Watch the prereq checks, click through, enjoy the phonk
5. Wait for install to complete (~2–5 min on first run, longer if pulling images)
6. Click **★ OPEN BOOKSTACK ★** when it appears
7. Log in with `admin@admin.com` / `password` and change your credentials

---

## File Structure

```
BookStack-Installer/
├── START.bat                  ← Run this
├── server.ps1                 ← PowerShell HTTP server (no installs needed)
├── web/
│   └── demoscene.html         ← The UI (self-contained, MP3 embedded)
└── scripts/
    └── installBookstack.ps1   ← The actual BookStack installer
```

---

## Where BookStack is installed

The installer creates everything in:
```
%USERPROFILE%\docker\bookstack\
├── compose.yaml               ← Docker Compose config
├── credentials.txt            ← Generated passwords (keep private!)
└── bookstack-config\          ← BookStack data volume
```

BookStack runs on **http://localhost:6875**

---

## How it works (technically)

### server.ps1
Pure PowerShell HTTP server using `System.Net.HttpListener` (.NET built-in, zero installs).

| Endpoint | Description |
|---|---|
| `GET /demoscene.html` | Serves the UI |
| `GET /healthcheck` | Checks Docker, RAM, CPU, disk — returns JSON |
| `GET /stream` | Runs `installBookstack.ps1`, streams output via Server-Sent Events |

### demoscene.html
- Self-contained (~5MB — phonk MP3 embedded as base64)
- Prerequisites screen checks `/healthcheck` sequentially with delays
- SSE client receives install output line by line, renders in the monitor
- JS polls BookStack URL every 3s after `__URL__:` marker is received
- Canvas animation: plasma background, VHS effects, rotating cube, artifact blobs, scrolltext

### installBookstack.ps1
- Generates a BookStack `APP_KEY` via Docker
- Creates random secure DB passwords
- Writes `compose.yaml` + starts containers with `docker compose up -d`
- Emits `__URL__:http://localhost:6875` for the browser to start polling
- Streams `docker compose logs --follow` until interrupted

---

## Development

```powershell
# Start the development server
.\server.ps1

# Start with mock installer (for testing without Docker pull)
.\server.ps1 -Script mock-install.ps1

# Use a specific port
.\server.ps1 -Port 9090

# Sync changes to release folder
.\build-release.ps1
```

### Known quirk
`HttpListener` registers URL prefixes in Windows HTTP namespace. If the server crashes without cleanup, restart on a different port:
```powershell
.\server.ps1 -Port 9091
```

---

## Removing BookStack

```powershell
cd "$HOME\docker\bookstack"
docker compose down -v
docker rmi lscr.io/linuxserver/bookstack:latest lscr.io/linuxserver/mariadb:latest
Remove-Item "$HOME\docker\bookstack" -Recurse -Force
```

---

## Credits

- **Phonk track**: *Brazilian Phonk* by Alex Morgan — [Pixabay](https://pixabay.com)
- **Installer**: Ferit — for WOOK!
- **BookStack**: [bookstackapp.com](https://www.bookstackapp.com)
- **Docker images**: [linuxserver.io](https://linuxserver.io)
