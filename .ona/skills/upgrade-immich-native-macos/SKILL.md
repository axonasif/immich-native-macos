---
name: upgrade-immich-native-macos
description: Upgrade the immich-native-macos project to a new upstream Immich release. Use when asked to update, upgrade, or bump the Immich version. Triggers on "upgrade immich", "update to latest immich", "bump immich version", "support new immich release".
---

# Upgrade immich-native-macos

Upgrade this project to track a new upstream [immich-app/immich](https://github.com/immich-app/immich) release.

## Prerequisites

The upstream immich repo must be cloned locally. If not already available:

```sh
git clone https://github.com/immich-app/immich /workspaces/immich
cd /workspaces/immich && git checkout <target-tag>
```

## Workflow

### 1. Investigate upstream changes

This is the most important step. Do not skip or abbreviate it.

The upgrade is not just version bumps. Upstream may have introduced new dependencies, changed build processes, added/removed services, restructured code, renamed environment variables, or changed how components communicate. You must understand the full scope of changes before modifying any files.

#### Diff the upstream tags

Find the current tag from `Scripts/config.env` (`IMMICH_TAG`), then diff against the target:

```sh
cd /workspaces/immich
git diff <old-tag>..<new-tag> -- \
  server/Dockerfile \
  machine-learning/Dockerfile \
  machine-learning/pyproject.toml \
  machine-learning/immich_ml/__main__.py \
  machine-learning/immich_ml/config.py \
  docker/docker-compose.yml \
  package.json \
  pnpm-workspace.yaml \
  plugins/mise.toml \
  plugins/package.json \
  server/package.json
```

If the diff is large, read each file individually at the target tag instead.

#### What to look for

- **New or removed services**: Does the docker-compose add a new container? Remove one? This could mean a new launchd plist or start script is needed.
- **Dockerfile build step changes**: New `COPY` directives, new build stages, changed `pnpm --filter` chains, new environment variables in build commands. Every `COPY --from=` in the final stage represents an artifact that `build_pkg.sh` must produce.
- **ML launcher changes**: Compare `machine-learning/immich_ml/__main__.py` — how gunicorn is invoked, what env vars control binding, any new CLI flags. The native start script must mirror this exactly.
- **ML dependency changes**: Check `machine-learning/pyproject.toml` for new required extras, changed Python version constraints, or new system-level dependencies.
- **New workspace packages**: Check `pnpm-workspace.yaml` for new packages that might need to be included in build filter chains.
- **Environment variable changes**: Check `server/src/dtos/env.dto.ts` and `server/src/repositories/config.repository.ts` for new/renamed/removed env vars that affect the `immich_server.env` template.
- **Plugin build changes**: Check `plugins/mise.toml` and `plugins/package.json` for new tools or changed build process.
- **Database changes**: Check if `DB_VECTOR_EXTENSION` options changed, or if new PostgreSQL extensions are required.
- **New runtime dependencies**: Check Dockerfiles for new `apt-get install` packages that would need Homebrew equivalents.

Do not limit your investigation to the files listed above. If the diff reveals changes in unexpected areas, follow them. The goal is to fully understand what changed before making any edits.

### 2. Collect new version values

Read `references/version-sources.md` for where to find each version. Collect:

- **Immich tag**
- **ffmpeg version** (from base-images repo, not the immich repo)
- **VectorChord version** (from docker-compose postgres image tag)
- **Python version** (from ML Dockerfile base image)
- Any new version-pinned dependencies discovered in step 1

### 3. Update project files

Read `references/file-map.md` for which files to modify and what each controls. For every file, read it first, then apply changes.

Apply version bumps, but also apply any structural changes discovered in step 1: new build steps, changed launch mechanisms, new environment variables, new brew dependencies, etc.

### 4. Verify no stale references

Grep for old version strings across the project:

```sh
grep -rn "old_tag\|old_python\|old_vectorchord\|old_ffmpeg" \
  --include="*.sh" --include="*.env" --include="*.yml" --include="*.md" .
```

### 5. Review the diff

Run `git diff` and verify every change is intentional and consistent across files. Cross-reference against the upstream diff from step 1 to confirm nothing was missed.

## Anti-patterns

- **Do not skip the upstream diff.** Blindly bumping versions will break the build if upstream changed build steps, dependencies, or launch mechanisms.
- Do not blindly copy Docker-specific configuration (e.g. `NVIDIA_*` env vars, Docker volume mounts, multi-arch `TARGETPLATFORM` logic).
- Do not change the launchd plist files unless the start script interface changed.
- Do not modify `uninstall.sh`, `createuser.sh`, `configurepostgres.sh`, or `createlog.sh` unless the upgrade specifically requires it — these are stable infrastructure scripts.
- Do not remove the `MACHINE_LEARNING_HOST`/`MACHINE_LEARNING_PORT` env vars from `immich_server.env` — the server uses these to locate the ML service, even though the ML process itself may use different env vars for binding.
