# File Map

Project files and what each controls. Only files that may need changes during an upgrade are listed.

## Scripts/config.env

Central version configuration. All other scripts source this file.

| Variable | Purpose |
|---|---|
| `IMMICH_TAG` | Git tag to clone from upstream |
| `FFMPEG_VERSION` | jellyfin-ffmpeg release version |

Directory paths and user/group settings are stable and rarely change.

## Scripts/installdependencies.sh

Installs runtime dependencies via Homebrew and builds VectorChord from source.

**Upgrade-sensitive sections:**
- `brew install` package list — Python version, new tools (e.g. `mise`, `uv`)
- `VECTORCHORD_VERSION` — must match upstream's docker-compose postgres image tag
- Rust/cargo pgrx build flags — only if VectorChord's build process changes

## Scripts/configureimmich.sh

Creates start scripts and the default `immich_server.env` configuration.

**Two start scripts:**
1. **Server** (`server/start.sh`): Runs `node ./dist/main`. Rarely changes.
2. **Machine Learning** (`machine-learning/start.sh`): Must match upstream's `__main__.py` launch method. This is the most likely script to change between versions.

**Environment template** (`immich_server.env`): Review for new/removed env vars. Check upstream's `server/src/repositories/config.repository.ts` and `server/src/dtos/env.dto.ts` for env var definitions.

## build_pkg.sh

Builds immich from source. Contains four build functions:

| Function | What to compare against |
|---|---|
| `build_immich` | `server/Dockerfile` — pnpm filter chains, SHARP flags, new workspace packages |
| `build_immich_machine_learning` | `machine-learning/Dockerfile` — Python version, uv flags |
| `fetch_immich_geodata` | Stable. Only changes if geodata sources change. |
| `clone_immich` | Stable. Only changes if build metadata env vars change. |

## .github/workflows/create-pkg.yml

CI workflow. Update the `brew install` list to match `installdependencies.sh` (build-only deps, not runtime deps like postgresql/redis).

## README.md

User-facing documentation. Update:
- Default port numbers if they changed
- Build dependency list (must match CI workflow)
- Any new notes about compatibility

## Files that rarely change

These are stable and should not be modified unless the upgrade specifically requires it:
- `Scripts/createuser.sh` — macOS user/group creation
- `Scripts/configurepostgres.sh` — database setup
- `Scripts/createlog.sh` — log file creation
- `Scripts/preinstall` / `Scripts/postinstall` — installer hooks
- `launchd/*.plist` — launchd job definitions (only if start script paths change)
- `uninstall.sh` — removal script
