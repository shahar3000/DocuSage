# DocuSage — Ask your product manuals

DocuSage is a self-hosted system that lets your team ask questions in plain language
against a collection of **PDF user manuals** and get answers **with citations** back to
the exact page/section. Everything runs locally — no documents leave your network.

It is tuned for **Hebrew and English**: the default answer model is Hebrew-specialized
(DictaLM, by Dicta) and the embeddings are multilingual, so manuals and questions in
either language work well.

It bundles a pre-wired Docker Compose stack, so there's nothing to configure:

- **Ollama** — runs the local AI model and the embeddings, on your hardware.
- **Open WebUI** — the web chat interface, with user accounts and an admin panel.
- **Docling** — a layout-aware PDF reader that correctly handles tables, multi-column
  pages, and diagrams (the part most manuals depend on).

(A one-shot helper container downloads the AI models on first run, then exits.)

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
- Then it asks **a few questions**. Just **press Enter** for each default, or:
  1. **Use GPU acceleration?** — type `y` if the machine has an NVIDIA GPU, otherwise `n`.
  2. **Which Hebrew answer model?** — both are Hebrew-specialized (by Dicta):
     - **`1` DictaLM 2.0** (7B) — needs ~8 GB RAM on CPU, or ~6 GB VRAM. Fast; runs on almost
       anything. *(the default on most machines)*
     - **`2` DictaLM 3.0** (24B) — needs a GPU with ~24 GB VRAM (e.g. RTX 3090/4090, A6000).
       Best Hebrew quality.

     The installer suggests `2` only when it detects a big-enough GPU, and warns you if you
     pick it on weaker hardware.
  3. **Port for the web interface?** — `3000` is fine.
  4. **Where to store data?** — `./data` is fine.

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

## Scanned manuals & OCR (admin)

Most product manuals are **digital PDFs** — the text is real and selectable, so DocuSage
reads them directly and fast. (To check a file: open it and try to highlight a sentence.
If you can select the text, it's digital.)

**OCR** (Optical Character Recognition) reads text out of *images*. It's only needed for
**scanned or photographed** manuals — where the page is a picture and you *cannot* select
the text. DocuSage keeps OCR **off by default**, because it's slow (several minutes per
document) and adds nothing for digital PDFs. Docling still extracts the text, tables, and
layout from digital PDFs with OCR off — OCR is only the fallback for image-only pages.

If you ever need to add a **scanned** manual, the admin can turn OCR on from the web
interface — no terminal needed. It is a **global** switch (it affects every upload while
it's on, and there's no per-file option yet), so the flow is: turn it on, upload the
scanned file, turn it back off.

1. Go to **Admin Panel → Settings → Documents**. Under the document-extraction (Docling)
   settings, find the **Docling parameters** field — a box containing text that starts with
   `{"do_ocr": ...}`.
2. **Turn OCR on:** replace the contents of that box with the following, then **Save**:

   `{"do_ocr": true, "do_table_structure": true, "table_mode": "accurate"}`

3. **Upload** the scanned manual into its Knowledge collection. This will be slow (a few
   minutes per document) — that's expected with OCR on.
4. **Turn OCR back off** when you're done: replace the box with the following and **Save**:

   `{"do_ocr": false, "do_table_structure": true, "table_mode": "accurate"}`

Only the `true` / `false` differs between the two. This setting is saved in the app and
stays as you left it, which is exactly why step 4 matters — leave it on the **off** value
so uploads stay fast for everyone.

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

- **Change the answer model:** edit `GENERATION_MODEL` in `.env` to switch between
  `aminadaven/dictalm2.0-instruct` (DictaLM 2.0, 7B) and `dicta-il/DictaLM-3.0-24B-Thinking`
  (DictaLM 3.0, 24B — needs ~24 GB VRAM), or any other Ollama model, then
  `docker compose up -d`. The new model is pulled automatically.
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
