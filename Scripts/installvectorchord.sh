#!/bin/sh

set -eux

echo "INFO: install VectorChord extension"

# Re-run script as main user (needs access to brew)
if [ "$USER" != "$(whoami)" ]; then
    su -l "$USER" -c "$0"
    exit
fi

pg_config="$(brew --prefix postgresql@17)/bin/pg_config"
pg_pkglibdir="$("$pg_config" --pkglibdir)"
pg_sharedir="$("$pg_config" --sharedir)/extension"

# Copy prebuilt extension files into PostgreSQL directories
cp "$IMMICH_APP_DIR/vectorchord/lib"/* "$pg_pkglibdir/"
cp "$IMMICH_APP_DIR/vectorchord/extension"/* "$pg_sharedir/"

# Configure shared_preload_libraries
sed -E -i "" "s|^#?shared_preload_libraries .*$|shared_preload_libraries = 'vchord.dylib'|" "$(brew --prefix)/var/postgresql@17/postgresql.conf"

# Restart PostgreSQL to load the extension
brew services restart postgresql@17
