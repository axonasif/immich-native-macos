#!/bin/sh

set -eu

if [ "${1:-}" = "-v" ]; then
    set -x
fi

clone_immich() {
    git_tag="$1"
    repo_dir="$2"
    conf_dir="$3"

    # Clone the repository
    if [ ! -d "$repo_dir" ]; then
        git clone --depth 1 --branch "$git_tag" https://github.com/immich-app/immich "$repo_dir"
    fi

    # Dump information about the build revision
    mkdir -p "$conf_dir"
    cat << EOF > "$conf_dir/build_info.env"
# Build information
IMMICH_BUILD=""
IMMICH_BUILD_URL=""
IMMICH_BUILD_IMAGE=""
IMMICH_BUILD_IMAGE_URL=""
IMMICH_REPOSITORY="immich-app/immich"
IMMICH_REPOSITORY_URL="$(git -C "$repo_dir" remote get-url origin)"
IMMICH_SOURCE_REF=""
IMMICH_SOURCE_COMMIT="$(git -C "$repo_dir" rev-parse HEAD)"
IMMICH_SOURCE_URL=""

EOF
}

build_immich() {
    repo_dir="$1"
    dest_dir="$2"
    cd "$repo_dir"

    # Build server backend
    SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm --filter immich --frozen-lockfile build
    SHARP_FORCE_GLOBAL_LIBVIPS=true pnpm --filter immich --frozen-lockfile --prod --no-optional deploy "$dest_dir/server"

    # Build web frontend (i18n is required since v2.5)
    pnpm --filter @immich/sdk --filter immich-web --frozen-lockfile --force install
    pnpm --filter @immich/sdk --filter immich-web build
    mkdir -p "$dest_dir/build"
    cp -R ./web/build "$dest_dir/build/www"

    # Build CLI
    pnpm --filter @immich/sdk --filter @immich/cli --frozen-lockfile install
    pnpm --filter @immich/sdk --filter @immich/cli build
    pnpm --filter @immich/cli --prod --no-optional deploy "$dest_dir/cli"

    # Build plugins (scope mise to only the plugins config to avoid installing unrelated monorepo tools)
    MISE_TRUSTED_CONFIG_PATHS="$(pwd)/plugins/mise.toml" mise --yes --cd plugins build
    mkdir -p "$dest_dir/build/corePlugin/dist"
    cp ./plugins/manifest.json "$dest_dir/build/corePlugin/manifest.json"
    cp -R ./plugins/dist "$dest_dir/build/corePlugin/dist"

    # Generate empty build lockfile
    echo "{}" > "$dest_dir/build/build-lock.json"

    cd -
}

build_immich_machine_learning() {
    repo_dir="$1"
    dest_dir="$2"

    # Build the machine learning backend
    cp -R "$repo_dir/machine-learning" "$dest_dir/"
    cd "$dest_dir/machine-learning"
    uv venv --relocatable --python "$(brew --prefix python@3.11)/bin/python3.11"
    uv sync --extra cpu
    cd -
}

build_vectorchord() {
    dest_dir="$1"
    vectorchord_version="$2"

    # Build VectorChord PostgreSQL extension from source
    vectorchord_staging_dir="$(mktemp -d -t vectorchord)"
    git clone --depth 1 --branch "$vectorchord_version" https://github.com/tensorchord/VectorChord "$vectorchord_staging_dir"

    # Install Rust toolchain and cargo-pgrx
    rustup-init --profile minimal --default-toolchain none -y
    export PATH="$HOME/.cargo/bin:$PATH"
    cargo install cargo-pgrx --version "=0.14.1" --locked

    # Build the extension against the local PostgreSQL
    cd "$vectorchord_staging_dir"
    pg_config="$(brew --prefix postgresql@17)/bin/pg_config"
    PGRX_PG_CONFIG_PATH="$pg_config" \
        cargo pgrx install \
        -p vchord \
        --features pg17 \
        --release \
        --pg-config "$pg_config"

    # Collect built extension files into the package
    pg_pkglibdir="$("$pg_config" --pkglibdir)"
    pg_sharedir="$("$pg_config" --sharedir)/extension"

    mkdir -p "$dest_dir/vectorchord/lib" "$dest_dir/vectorchord/extension"
    cp "$pg_pkglibdir"/vchord* "$dest_dir/vectorchord/lib/"
    cp "$pg_sharedir"/vchord* "$dest_dir/vectorchord/extension/"
    cp -a ./sql/upgrade/. "$dest_dir/vectorchord/extension/"

    cd -
    rm -rf "$vectorchord_staging_dir"
}

fetch_immich_geodata() {
    dest_dir="$1"

    # Download geodata
    mkdir -p "$dest_dir/build/geodata"
    curl -o "$dest_dir/build/geodata/cities500.zip" https://download.geonames.org/export/dump/cities500.zip
    unzip "$dest_dir/build/geodata/cities500.zip" -d "$dest_dir/build/geodata" && rm "$dest_dir/build/geodata/cities500.zip"
    curl -o "$dest_dir/build/geodata/admin1CodesASCII.txt" https://download.geonames.org/export/dump/admin1CodesASCII.txt
    curl -o "$dest_dir/build/geodata/admin2Codes.txt" https://download.geonames.org/export/dump/admin2Codes.txt
    curl -o "$dest_dir/build/geodata/ne_10m_admin_0_countries.geojson" https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson
    date -u +"%Y-%m-%dT%H:%M:%S%z" | tr -d "\n" > "$dest_dir/build/geodata/geodata-date.txt"
    chmod -R 444 "$dest_dir/build/geodata"/*
}

create_pkg() {
    root_dir="$1"
    out_pkg="$2"

    # Create PKG installer
    pkgbuild \
        --version "$IMMICH_TAG" \
        --root "$root_dir" \
        --identifier com.unofficial.immich.installer \
        --scripts ./Scripts \
        --install-location "/" \
        "$out_pkg"
}

# Load configuration environment
set -a
# shellcheck disable=SC1091
. ./Scripts/config.env
set +a
pkg_filename="Unofficial Immich Installer $IMMICH_TAG.pkg"

# Create staging directories
output_dir="$(pwd)/output"
staging_dir="$output_dir/staging"
root_dir="$staging_dir/root"
dist_dir="$root_dir/$IMMICH_APP_DIR"
conf_dir="$root_dir/$IMMICH_SETTINGS_DIR"
rm -rf "$staging_dir"
mkdir -p "$staging_dir" "$root_dir" "$dist_dir" "$output_dir"

# Build Immich from source
clone_immich "$IMMICH_TAG" "$staging_dir/immich" "$conf_dir"
build_immich "$staging_dir/immich" "$dist_dir"
build_immich_machine_learning "$staging_dir/immich" "$dist_dir"
build_vectorchord "$dist_dir" "$VECTORCHORD_VERSION"
fetch_immich_geodata "$dist_dir"

# Fix paths in generated root directory
grep -rlI --null "$root_dir" "$root_dir" | xargs -0 sed -i "" "s|$(realpath "$root_dir")||g"

# Copy PKG resources
mkdir -p "$root_dir/Library/LaunchDaemons"
find ./launchd -type f -name "*.plist" | while read -r f; do
    filename="$(basename "$f")"
    envsubst < "$f" > "$root_dir/Library/LaunchDaemons/$filename"
done

# Create PKG installer
create_pkg "$root_dir" "$output_dir/$pkg_filename"
echo "macOS installer created successfully in $output_dir/$pkg_filename"
