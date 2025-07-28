#!/bin/bash

# Load PostgreSQL password from build time
if [ -f /tmp/postgres_password ]; then
    export POSTGRES_PASSWORD=$(cat /tmp/postgres_password)
    echo "Using PostgreSQL password from build time"
else
    echo "Error: PostgreSQL password not found!"
    exit 1
fi

# Ensure appuser owns the .env files
chown appuser:appuser /pm-auth-api/.env.production /pm-identity-api/.env.production /pm-guardian-api/.env.production /pm-front/.env.production 2>/dev/null || true

# Start PostgreSQL
echo "Starting PostgreSQL 15 database server: main."
service postgresql start

# Wait for PostgreSQL to be fully ready
sleep 3

# Start auth API in background
cd /pm-auth-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8001 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100 wsgi:app
" &

# Start identity API in background
cd /pm-identity-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8002 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100 wsgi:app
" &

# Start guardian API in background
cd /pm-guardian-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8003 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100 wsgi:app
" &

# Start frontend application
cd /pm-front
sudo -u appuser bash -c "
    export NODE_ENV=production
    export AUTH_SERVICE_URL=http://localhost:8001
    export IDENTITY_SERVICE_URL=http://localhost:8002
    export GUARDIAN_SERVICE_URL=http://localhost:8003
    export NEXT_PUBLIC_AUTH_SERVICE_URL=http://localhost:8001
    export NEXT_PUBLIC_IDENTITY_SERVICE_URL=http://localhost:8002
    export NEXT_PUBLIC_GUARDIAN_SERVICE_URL=http://localhost:8003
    export LOG_LEVEL=debug
    npm start
" &

# Start Nginx as reverse proxy
echo "Starting Nginx reverse proxy..."
nginx

# Keep container running
wait
