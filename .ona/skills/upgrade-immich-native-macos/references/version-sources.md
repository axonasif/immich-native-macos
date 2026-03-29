# Version Sources

Where to find each version number in the upstream immich repo.

## Immich tag

The git tag itself (e.g. `v2.6.3`). Confirm with:
```sh
git -C /workspaces/immich log --oneline -1
```

## ffmpeg

Not in the immich repo. Fetched from the base-images repo:
```
https://github.com/immich-app/base-images/blob/main/server/packages/ffmpeg.json
```
Use `web_read` to fetch the current version.

## VectorChord

Embedded in the postgres Docker image tag in `docker/docker-compose.yml`:
```
image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:...
```
Extract the version after `vectorchord` (e.g. `0.4.3`).

## Python version

From `machine-learning/Dockerfile`, check the base builder image:
```dockerfile
FROM python:3.11-bookworm@sha256:... AS builder-cpu
```
The minor version (e.g. `3.11`) determines which `python@X.Y` brew package to use.

Also verify against `machine-learning/pyproject.toml`:
```toml
requires-python = ">=3.11,<4.0"
```

## pnpm version

From the root `package.json`:
```json
"packageManager": "pnpm@10.30.3+sha512:..."
```
Not typically needed for the native build (brew installs pnpm), but useful for troubleshooting version mismatches.

## Sharp flags

From `server/Dockerfile`, check the build and deploy commands:
```dockerfile
SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm --filter immich --frozen-lockfile build
SHARP_FORCE_GLOBAL_LIBVIPS=true pnpm --filter immich --frozen-lockfile --prod --no-optional deploy ...
```

## ML launch method

From `machine-learning/immich_ml/__main__.py` — this defines how the ML process starts (gunicorn config, bind address, workers). The native start script must mirror this.

Check `machine-learning/immich_ml/config.py` for `NonPrefixedSettings` to see which env vars control host/port binding.

## Plugins build tools

From `plugins/mise.toml` — lists the tools needed to build plugins (extism-cli, binaryen, js-pdk).
