# DocuSage — Ask your product manuals

DocuSage is a self-hosted system that lets your team ask questions in plain language
against a collection of **PDF user manuals** and get answers **with citations** back to
the exact page/section. Everything runs locally — no documents leave your network.

It bundles three containers, pre-wired so there's nothing to configure:

- **Ollama** — runs the local AI model and the embeddings, on your hardware.
- **Open WebUI** — the web chat interface, with user accounts and an admin panel.
- **Docling** — a layout-aware PDF reader that correctly handles tables, multi-column
  pages, and diagrams (the part most manuals depend on).

---

## Setup — step by step

You need a **Linux machine** (a physical box, a VM, or a cloud server). These steps take it
from nothing to a working DocuSage. Copy and paste each block into a terminal.

**1. Open a terminal on the Linux machine.**

**2. Download DocuSage** (this also installs `git` if it isn't already there):

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/shahar3000/DocuSage.git
cd DocuSage
```

> On Ubuntu/Debian the commands above work as-is. On other Linux families, install `git`
> with that system's package manager (e.g. `sudo dnf install -y git`), then run the same
> `git clone` and `cd` lines.

**3. Run the installer:**

```bash
./install.sh
```

- It may ask for **your password** the first time — that's it installing Docker. Normal.
- Then it asks **three questions**. Just **press Enter** for each default, or:
  1. **Use GPU acceleration?** — type `y` if the machine has an NVIDIA GPU, otherwise `n`.
  2. **Port for the web interface?** — `3000` is fine.
  3. **Where to store data?** — `./data` is fine.

> If you get `permission denied`, run `chmod +x install.sh` once, then `./install.sh` again.

**4. Wait for it to finish.** The first run downloads several gigabytes (the software images
plus the AI models), so it can take **10–20 minutes**. When it's done it prints a link like:

```
On this machine : http://localhost:3000
From the team   : http://192.168.x.x:3000
```

**5. Open that link in a web browser.** Use the `localhost` link on the machine itself, or
the `192.168.x.x` link from another computer on the same network.

**6. Create the first account.** The **first** person to sign up automatically becomes the
**admin**. Continue with the next sections to add your team and your manuals.

---

## Add your team (admin)

Once you're logged in as the admin:

1. Go to **Admin Panel → Users → ➕ Add User** and create an account for each person.
2. New self-signups are held as **pending** (no access) until you activate them, so access
   is admin-controlled out of the box.
3. To turn off self-signup entirely: **Admin Panel → Settings → General → disable new
   sign-ups** (or set `ENABLE_SIGNUP=false` in `.env` and run `docker compose up -d`).

---

## Adding manuals

1. Go to **Workspace → Knowledge** and create a collection — **one per product** works
   well (e.g. "Acme Drill X200", "Acme Saw S50").
2. Drag-and-drop that product's PDF(s) into the collection. They're parsed by Docling and
   indexed automatically. You can add more manuals or new product collections **anytime**,
   no restart needed.

## Asking questions

In a chat, type `#` to attach the relevant product's Knowledge collection, then ask your
question. Answers include **inline citations** linking to the source document and the exact
text used — click them to verify. Attaching a single product's collection keeps answers
scoped to that manual.

---

## Day-to-day operations

All commands run from this folder.

| Task | Command |
|---|---|
| Stop everything | `docker compose down` |
| Start again | `docker compose up -d` |
| View logs | `docker compose logs -f open-webui` |
| Update to latest versions | `docker compose pull && docker compose up -d` |
| Back up | copy the data directory (default `./data`) — it holds models, accounts, and manuals |

---

## Uninstall

To remove DocuSage completely and leave the machine as it was (Docker stays installed):

```bash
./uninstall.sh
```

It stops the containers, removes the pulled images, and wipes the data directory
(models, accounts, manuals). It deletes the data from inside a throwaway container, so it
works **without `sudo`** even though some files are root-owned. Add `--yes` to skip the
confirmation prompt.

---

## Tuning & scaling (optional, later)

- **Bigger/better answers:** edit `GENERATION_MODEL` in `.env` (e.g. `qwen2.5:14b` or
  `qwen2.5:32b` if you have the GPU memory), then `docker compose up -d`. The new model is
  pulled automatically.
- **More manuals (hundreds–thousands):** the default vector store handles a small corpus
  well. To grow, switch Open WebUI's `VECTOR_DB` to pgvector/Qdrant/Milvus (add the service
  to `docker-compose.yml`) and re-index.
- **Higher retrieval precision:** enable hybrid search + a reranker. Set
  `ENABLE_RAG_HYBRID_SEARCH=true` and configure a reranking model on the `open-webui`
  service. (Left off by default because the reranker downloads on first query and can fail
  on an offline host.)

---

## Files in this project

| File | Purpose |
|---|---|
| `install.sh` | The one-command interactive installer (Linux) |
| `uninstall.sh` | Clean removal — containers, images, and all data (no sudo needed) |
| `docker-compose.yml` | The full stack, with all RAG settings pre-configured |
| `docker-compose.gpu.yml` | GPU override, layered on automatically when you choose GPU |
| `.env.example` | Default settings template |
| `.env` | Your actual settings (created by `install.sh`) |
