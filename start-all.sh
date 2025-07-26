#!/bin/bash

# Generate JWT secret if not provided
if [ -z "$JWT_SECRET" ]; then
    export JWT_SECRET=$(openssl rand -hex 32)
    echo "Generated JWT_SECRET: $JWT_SECRET"
else
    echo "Using provided JWT_SECRET"
fi

# Generate Internal Auth Token if not provided
if [ -z "$INTERNAL_AUTH_TOKEN" ]; then
    export INTERNAL_AUTH_TOKEN=$(openssl rand -hex 32)
    echo "Generated INTERNAL_AUTH_TOKEN: $INTERNAL_AUTH_TOKEN"
else
    echo "Using provided INTERNAL_AUTH_TOKEN"
fi

# Generate PostgreSQL password if not provided
if [ -z "$POSTGRES_PASSWORD" ]; then
    export POSTGRES_PASSWORD=$(openssl rand -base64 32)
    echo "Generated POSTGRES_PASSWORD"
else
    echo "Using provided POSTGRES_PASSWORD"
fi

# Ensure appuser owns the .env files
chown appuser:appuser /pm-auth-api/.env.production /pm-identity-api/.env.production /pm-guardian-api/.env.production 2>/dev/null || true

# Add secrets to auth API .env file
echo "JWT_SECRET=$JWT_SECRET" >> /pm-auth-api/.env.production
echo "INTERNAL_AUTH_TOKEN=$INTERNAL_AUTH_TOKEN" >> /pm-auth-api/.env.production

# Configure PostgreSQL with new user
echo "Starting PostgreSQL 15 database server: main."
service postgresql start

# Wait for PostgreSQL to be fully ready
sleep 3

# Create new user with generated password
echo "Creating PostgreSQL user 'appdb' with generated password..."
su postgres -c "psql -c \"CREATE USER appdb WITH PASSWORD '$POSTGRES_PASSWORD';\""
su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE auth_db TO appdb;\""
su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE identity_db TO appdb;\""
su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE guardian_db TO appdb;\""

# Grant schema permissions for migrations
su postgres -c "psql -d auth_db -c \"GRANT ALL ON SCHEMA public TO appdb;\""
su postgres -c "psql -d identity_db -c \"GRANT ALL ON SCHEMA public TO appdb;\""
su postgres -c "psql -d guardian_db -c \"GRANT ALL ON SCHEMA public TO appdb;\""

# Update database URLs in all .env files with the new user and password
sed -i "s|DATABASE_URL=postgresql://.*@localhost.*/auth_db|DATABASE_URL=postgresql://appdb:$POSTGRES_PASSWORD@localhost:5432/auth_db|g" /pm-auth-api/.env.production
sed -i "s|DATABASE_URL=postgresql://.*@localhost.*/identity_db|DATABASE_URL=postgresql://appdb:$POSTGRES_PASSWORD@localhost:5432/identity_db|g" /pm-identity-api/.env.production
sed -i "s|DATABASE_URL=postgresql://.*@localhost.*/guardian_db|DATABASE_URL=postgresql://appdb:$POSTGRES_PASSWORD@localhost:5432/guardian_db|g" /pm-guardian-api/.env.production

# Start auth API in background
cd /pm-auth-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8001 wsgi:app
" &

# Start identity API in background
cd /pm-identity-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8002 wsgi:app
" &

# Start guardian API in background
cd /pm-guardian-api
sudo -u appuser bash -c "
    source venv/bin/activate
    export FLASK_ENV=production
    export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
    ./wait-for-it.sh localhost:5432 --timeout=60 --strict
    flask db upgrade
    gunicorn -w 4 -b 127.0.0.1:8003 wsgi:app
" &

# Start frontend application
cd /pm-front
sudo -u appuser bash -c 'npm start' &

# Keep container running
wait
