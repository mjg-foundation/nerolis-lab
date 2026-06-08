set shell := ["bash", "-cu"]

default:
  @just --list

backend-env:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f backend/.env ]; then
    printf '%s\n' \
      'DB_HOST=localhost' \
      'DB_PORT=3306' \
      'DB_USER=root' \
      'DB_PASS=admin' \
      'DATABASE_MIGRATION=UP' \
      'DATABASE_NAME=pokemonsleep' \
      > backend/.env
    echo "created backend/.env with local defaults"
  else
    echo "backend/.env already exists"
  fi

sync-nix-deps:
  #!/usr/bin/env bash
  set -euo pipefail

  link_node_modules() {
    local name="$1"
    local dir="$2"
    local out
    out="$(nix build --no-link --print-out-paths ".#${name}-node-modules")"
    rm -rf "${dir}/node_modules"
    ln -s "${out}/node_modules" "${dir}/node_modules"
    echo "linked ${dir}/node_modules -> ${out}/node_modules"
  }

  link_node_modules root .
  link_node_modules common common
  link_node_modules backend backend
  link_node_modules frontend frontend
  link_node_modules guides guides
  link_node_modules docs docs

sync-runtime-nix-deps:
  #!/usr/bin/env bash
  set -euo pipefail

  for name in common backend; do
    out="$(nix build --no-link --print-out-paths ".#${name}-node-modules")"
    rm -rf "${name}/node_modules"
    ln -s "${out}/node_modules" "${name}/node_modules"
    echo "linked ${name}/node_modules -> ${out}/node_modules"
  done

clean-nix-deps:
  #!/usr/bin/env bash
  set -euo pipefail
  for dir in . common backend frontend guides docs; do
    if [ -L "${dir}/node_modules" ]; then
      rm "${dir}/node_modules"
      echo "removed ${dir}/node_modules"
    fi
  done

frontend-deps:
  nix develop --command bash -lc 'cd frontend && npm install'

backend-deps:
  nix develop --command bash -lc 'cd backend && npm install'

common-build:
  nix develop --command bash -lc 'cd common && npm run clean && npm run build-rollup'

website-setup:
  just backend-env
  just db-up
  just backend-deps
  just common-build
  just frontend-deps

build:
  if [ -L common/node_modules ]; then cd common && npm run clean && npm run build-rollup; else cd common && npm run build; fi
  cd backend && npm run build
  if [ -L frontend/node_modules ]; then cd frontend && npm run clean && npm run type-check && npm run build-only; else cd frontend && npm run build; fi
  cd guides && npm run build
  cd docs && npm run build

db-up:
  cd backend && docker compose up -d

db-down:
  cd backend && docker compose down

common:
  if [ -L common/node_modules ]; then cd common && npm run clean && npm run build-rollup -- --watch; else cd common && npm run build-watch; fi

backend:
  nix develop --command bash -lc 'cd backend && if [ -L node_modules ]; then bun --watch src/app.ts; else npm run dev; fi'

frontend:
  nix develop --command bash -lc 'cd frontend && npm run dev'

guides:
  nix develop --command bash -lc 'cd guides && npm run dev'

docs:
  nix develop --command bash -lc 'cd docs && npm run dev'

test:
  cd common && npm run test
  cd backend && npm run test
  cd frontend && npm run test
  cd guides && npm run test
  cd docs && npm run test
