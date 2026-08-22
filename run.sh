#!/usr/bin/env bash
# Convenience script: create a venv (first run only), install deps, start the API.
set -e

cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit SECRET_KEY before deploying anywhere real."
fi

exec uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
