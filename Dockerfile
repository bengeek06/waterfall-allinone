FROM debian:bookworm

# Update image
RUN apt-get update -y && apt-get upgrade -y

# Install postgresql
RUN apt-get install -y postgresql postgresql-contrib

# Create databases (passwords will be set dynamically in start-all.sh)
RUN service postgresql start && \
    su - postgres -c "psql -c \"CREATE DATABASE auth_db;\"" && \
    su - postgres -c "psql -c \"CREATE DATABASE identity_db;\"" && \
    su - postgres -c "psql -c \"CREATE DATABASE guardian_db;\""

# Install git and openssl
RUN apt-get install -y git openssl curl

# Install Python and pip
RUN apt-get install -y python3 python3-pip

# Clone backend repositories
RUN git clone https://github.com/bengeek06/pm-auth-api.git
RUN git clone https://github.com/bengeek06/pm-identity-api.git
RUN git clone https://github.com/bengeek06/pm-guardian-api.git

# Make wait-for-it.sh executable
RUN chmod +x pm-auth-api/wait-for-it.sh
RUN chmod +x pm-identity-api/wait-for-it.sh
RUN chmod +x pm-guardian-api/wait-for-it.sh

# Install Python virtual environment
RUN pip3 install --break-system-packages virtualenv
RUN virtualenv -p python3 pm-auth-api/venv
RUN virtualenv -p python3 pm-identity-api/venv
RUN virtualenv -p python3 pm-guardian-api/venv

# Install Python dependencies
RUN pm-auth-api/venv/bin/pip install -r pm-auth-api/requirements.txt
RUN pm-identity-api/venv/bin/pip install -r pm-identity-api/requirements.txt
RUN pm-guardian-api/venv/bin/pip install -r pm-guardian-api/requirements.txt

# Create .env files (database URLs will be updated dynamically in start-all.sh)
RUN echo "DATABASE_URL=postgresql://postgres:placeholder@localhost/auth_db" > pm-auth-api/.env.production
RUN echo "FLASK_ENV=production" >> pm-auth-api/.env.production
RUN echo "USER_SERVICE_URL=http://localhost:8002" >> pm-auth-api/.env.production
RUN echo "LOG_LEVEL=info" >> pm-auth-api/.env.production

RUN echo "DATABASE_URL=postgresql://postgres:placeholder@localhost/identity_db" > pm-identity-api/.env.production
RUN echo "FLASK_ENV=production" >> pm-identity-api/.env.production
RUN echo "AUTH_SERVICE_URL=http://localhost:8001" >> pm-identity-api/.env.production
RUN echo "LOG_LEVEL=info" >> pm-identity-api/.env.production

RUN echo "DATABASE_URL=postgresql://postgres:placeholder@localhost/guardian_db" > pm-guardian-api/.env.production
RUN echo "FLASK_ENV=production" >> pm-guardian-api/.env.production

# Install Gunicorn and Flask-Migrate in each virtual environment
RUN pm-auth-api/venv/bin/pip install gunicorn
RUN pm-identity-api/venv/bin/pip install gunicorn
RUN pm-guardian-api/venv/bin/pip install gunicorn

# Clone frontend repository with NextJS 15 fixes
RUN git clone --branch fix/nextjs15-params-compatibility https://github.com/bengeek06/pm-front.git

# Install npm and Node.js
RUN apt-get install -y npm
RUN npm install -g n

# Start Node.js and install dependencies
RUN n stable
RUN cd pm-front && npm install
RUN cd pm-front && npm run build

# Install sudo for user management
RUN apt-get install -y sudo

# Create non-root user for running services
RUN useradd -m -s /bin/bash appuser

# Set ownership for essential files and scripts
RUN chown appuser:appuser /pm-auth-api /pm-identity-api /pm-guardian-api /pm-front
RUN chown appuser:appuser /pm-auth-api/wait-for-it.sh /pm-identity-api/wait-for-it.sh /pm-guardian-api/wait-for-it.sh

# Expose ports for the applications
EXPOSE 3000

# Start backend and frontend applications
COPY start-all.sh /start-all.sh
RUN chmod +x /start-all.sh
CMD ["/bin/bash", "/start-all.sh"]
