# CLAUDE.md

Guidance for working in this repository.

## Project overview

**DocuSage** is a self-hosted RAG (Retrieval-Augmented Generation) system that lets a team
ask questions against a collection of **PDF user manuals** and get answers with citations.
Everything runs locally — documents never leave the network.

The whole thing is a Docker Compose stack delivered as a **single, zero-config install**:

- **Ollama** — runs the local generation model and the embedding model.
- **Open WebUI** — team chat UI, user accounts, and the RAG ("Knowledge") layer.
- **Docling** — layout-aware PDF parser (tables, multi-column, figures).
- **model-init** — one-shot container that pulls the models on first boot, then exits.

All RAG settings are pre-wired via environment variables in `docker-compose.yml`, so there
is no admin-UI configuration step.

## Key files

| File | Purpose |
|---|---|
| `install.sh` | Interactive one-command Linux installer (prompts: GPU / port / data dir) |
| `docker-compose.yml` | The full stack with all settings baked in as env vars |
| `docker-compose.gpu.yml` | NVIDIA override, layered on when GPU is selected |
| `.env.example` | Settings template; `install.sh` writes the real `.env` |
| `README.md` | End-user run / operate / add-manuals guide |

## Common commands

```bash
./install.sh                              # full interactive install
docker compose up -d                      # start (uses .env, incl. COMPOSE_FILE for GPU)
docker compose down                       # stop
docker compose logs -f open-webui         # tail UI logs
docker compose pull && docker compose up -d   # update images
```

The GPU choice is persisted in `.env` via `COMPOSE_FILE`, so plain `docker compose`
commands keep using the GPU override after install.

## Conventions

- Keep the install **zero-tech-knowledge**: no manual config files to edit, no admin-UI
  setup. New options should have sane defaults and, if interactive, a prompt with a default.
- Change behavior through **environment variables** in `docker-compose.yml` / `.env`, not
  by requiring post-launch clicking.
- Don't commit `.env` or `data/` (see `.gitignore`).

## Commit guidelines

- **One logical change per commit.** Each commit should stand on its own — don't bundle
  unrelated edits. Split mixed work into separate commits.
- **Informative messages.** Use a concise imperative subject line (≤ ~72 chars) and, when
  the change isn't self-evident, a body explaining *what* and *why*.
- **Always sign off** with `git commit -s` (adds the `Signed-off-by:` trailer).
- When a commit is co-authored with Claude, keep the
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.
- Commit or push only when asked.
