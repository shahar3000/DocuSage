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

## Install (one command)

On a **Linux** machine:

```bash
./install.sh
```

It asks three things (just press Enter for the defaults):

1. **Use GPU acceleration?** — defaults to yes if an NVIDIA GPU is found, otherwise CPU.
2. **Web UI port?** — default `3000`.
3. **Where to store data?** — default `./data`.

Then it installs Docker if needed, starts everything, downloads the models (a few minutes
the first time), and prints the URL to open. That's it.

> The only prerequisite the installer can't do for you on every distro is a running Docker
> daemon — it will install Docker via the official script, but you may need to start it
> (`sudo systemctl start docker`) if your system doesn't auto-start services.

---

## First-time setup in the browser

1. Open the printed URL. **The first account you create becomes the admin.**
2. Register your team: go to **Admin Panel → Users → ➕ Add User** and create an account
   for each person.
   - New self-signups are held as **pending** (no access) until you activate them, so
     access is admin-controlled out of the box.
   - To turn off self-signup entirely: **Admin Panel → Settings → General → disable new
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
| `docker-compose.yml` | The full stack, with all RAG settings pre-configured |
| `docker-compose.gpu.yml` | GPU override, layered on automatically when you choose GPU |
| `.env.example` | Default settings template |
| `.env` | Your actual settings (created by `install.sh`) |
