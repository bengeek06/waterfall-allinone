# Waterfall All-in-One

Une solution complète containerisée Docker pour déployer l'ensemble de la stack Waterfall avec sécurité renforcée et reverse proxy HTTPS.

## 🏗️ Architecture

Cette solution intègre :
- **3 APIs Flask** (Auth, Identity, Guardian) avec bases de données PostgreSQL dédiées
- **Frontend Next.js 15** en mode production
- **Reverse proxy Nginx** avec terminaison SSL/HTTPS
- **Sécurité renforcée** : utilisateur non-root, secrets dynamiques, isolation des APIs

```
┌─────────────────────────────────────────┐
│                Nginx                     │
│            (Port 80/443)                │
│          Reverse Proxy + SSL            │
└─────────────┬───────────────────────────┘
              │ HTTPS uniquement
              ▼
┌─────────────────────────────────────────┐
│            Next.js Frontend             │
│              (Port 3000)                │
│           APIs internes uniquement      │
└─────────────┬───────────────────────────┘
              │ Communication interne
              ▼
┌─────────────────────────────────────────┐
│          APIs Flask (Internes)          │
│  Auth:8001  Identity:8002  Guardian:8003│
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│            PostgreSQL 15                │
│   auth_db, identity_db, guardian_db     │
└─────────────────────────────────────────┘
```

## 🚀 Démarrage rapide

### Option A : Docker Compose (Recommandé)

```bash
# 1. Cloner et configurer
git clone <repository-url>
cd waterfall-allinone

# 2. Optionnel : Personnaliser les secrets
cp .env.example .env
# Éditez le fichier .env avec vos secrets personnalisés

# 3. Lancer avec Docker Compose
docker-compose up -d

# 4. Vérifier les logs
docker-compose logs -f
```

### Option B : Docker classique

```bash
# 1. Construction de l'image
docker build -t waterfall-app .

# 2. Lancement du conteneur
# Avec ports HTTPS/HTTP exposés
docker run --name waterfall -p 80:80 -p 443:443 waterfall-app

# Ou en arrière-plan
docker run -d --name waterfall -p 80:80 -p 443:443 waterfall-app
```

### 3. Accès à l'application

- **HTTPS** : https://localhost (recommandé)
- **HTTP** : http://localhost (redirige automatiquement vers HTTPS)

> ⚠️ **Certificat auto-signé** : Votre navigateur affichera un avertissement de sécurité. Cliquez sur "Avancé" puis "Continuer vers localhost" pour accepter le certificat.

## 🐳 Docker Compose

### Avantages de Docker Compose

- **Persistance des données** : Base de données PostgreSQL persistante
- **Gestion des secrets** : Configuration centralisée via fichier `.env`
- **Logs persistants** : Conservation des logs Nginx et PostgreSQL
- **Restart automatique** : Redémarrage automatique en cas de problème
- **Health checks** : Surveillance de la santé de l'application

### Configuration des secrets

1. **Copiez le fichier d'exemple** :
   ```bash
   cp .env.example .env
   ```

2. **Générez des secrets sécurisés** :
   ```bash
   # JWT Secret
   echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
   
   # Internal Auth Token  
   echo "INTERNAL_AUTH_TOKEN=$(openssl rand -hex 32)" >> .env
   
   # PostgreSQL Password
   echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
   ```

3. **Ou laissez vide** pour génération automatique au démarrage

### Gestion avec Docker Compose

```bash
# Démarrer en arrière-plan
docker-compose up -d

# Voir les logs en temps réel
docker-compose logs -f

# Redémarrer un service spécifique
docker-compose restart waterfall-app

# Arrêter tous les services
docker-compose down

# Arrêter et supprimer les volumes (⚠️ perte de données)
docker-compose down -v

# Reconstruire l'image
docker-compose build --no-cache

# Voir l'état des services
docker-compose ps
```

## 🔐 Sécurité

### Génération automatique des secrets

Au démarrage, le conteneur génère automatiquement :
- `JWT_SECRET` : Secret pour les tokens JWT (32 bytes hex)
- `INTERNAL_AUTH_TOKEN` : Token d'authentification inter-services (32 bytes hex)  
- `POSTGRES_PASSWORD` : Mot de passe PostgreSQL (32 bytes base64)

### Variables d'environnement personnalisées

Vous pouvez fournir vos propres secrets via les variables d'environnement :

```bash
docker run -d --name waterfall \
  -p 80:80 -p 443:443 \
  -e JWT_SECRET="votre_jwt_secret_personnalise" \
  -e INTERNAL_AUTH_TOKEN="votre_token_personnalise" \
  -e POSTGRES_PASSWORD="votre_mot_de_passe_postgres" \
  waterfall-app
```

### Architecture sécurisée

- **Utilisateur non-root** : Tous les services s'exécutent avec l'utilisateur `appuser`
- **APIs internes** : Les APIs Flask ne sont pas exposées directement
- **Base de données dédiée** : Utilisateur PostgreSQL `appdb` avec permissions limitées
- **Headers de sécurité** : HSTS, CSP, X-Frame-Options, etc.
- **Chiffrement** : Communication HTTPS obligatoire

## 📋 Gestion du conteneur

### Vérifier l'état du conteneur

```bash
# Statut du conteneur
docker ps

# Logs en temps réel
docker logs -f waterfall

# Logs des dernières 100 lignes
docker logs --tail 100 waterfall
```

### Arrêt et redémarrage

```bash
# Arrêter le conteneur
docker stop waterfall

# Redémarrer le conteneur
docker start waterfall

# Redémarrer avec nouveaux secrets
docker stop waterfall
docker rm waterfall
docker run -d --name waterfall -p 80:80 -p 443:443 waterfall-app
```

### Nettoyage

```bash
# Supprimer le conteneur
docker stop waterfall && docker rm waterfall

# Supprimer l'image
docker rmi waterfall-app

# Nettoyage complet Docker
docker system prune -a
```

## 🔍 Débogage et diagnostics

### Accès au conteneur

```bash
# Shell interactif dans le conteneur
docker exec -it waterfall /bin/bash

# Exécuter une commande spécifique
docker exec waterfall ps aux
```

### Vérification des services

```bash
# Vérifier les processus actifs
docker exec waterfall ps aux | grep -E "(nginx|gunicorn|npm)"

# Vérifier les ports d'écoute
docker exec waterfall netstat -tlnp

# Vérifier la base de données
docker exec waterfall su postgres -c "psql -c '\l'"
```

### Logs détaillés par service

```bash
# Logs PostgreSQL
docker exec waterfall tail -f /var/log/postgresql/postgresql-15-main.log

# Logs Nginx
docker exec waterfall tail -f /var/log/nginx/access.log
docker exec waterfall tail -f /var/log/nginx/error.log

# Vérifier les variables d'environnement générées
docker exec waterfall env | grep -E "(JWT_SECRET|INTERNAL_AUTH_TOKEN|POSTGRES_PASSWORD)"
```

### Test de connectivité interne

```bash
# Test des APIs internes
docker exec waterfall curl -s http://localhost:8001/version
docker exec waterfall curl -s http://localhost:8002/version  
docker exec waterfall curl -s http://localhost:8003/version

# Test du frontend
docker exec waterfall curl -s http://localhost:3000
```

## 🐛 Résolution de problèmes

### Le conteneur ne démarre pas

1. Vérifiez les logs : `docker logs waterfall`
2. Vérifiez les ports disponibles : `docker ps` et `netstat -tlnp | grep -E "(80|443)"`
3. Supprimez les conteneurs conflictuels : `docker rm -f $(docker ps -aq)`

### Erreur "port already allocated"

```bash
# Trouvez le processus utilisant le port
sudo lsof -i :80
sudo lsof -i :443

# Arrêtez les conteneurs utilisant ces ports
docker stop $(docker ps -q)
```

### PostgreSQL ne démarre pas

```bash
# Vérifiez l'espace disque
df -h

# Vérifiez les permissions
docker exec waterfall ls -la /var/lib/postgresql/

# Redémarrez PostgreSQL manuellement
docker exec waterfall service postgresql restart
```

### Les migrations échouent

```bash
# Vérifiez la connectivité à la base
docker exec waterfall su postgres -c "psql -c '\l'"

# Vérifiez l'utilisateur appdb
docker exec waterfall su postgres -c "psql -c '\du'"

# Relancez les migrations manuellement
docker exec waterfall su appuser -c "cd /pm-auth-api && source venv/bin/activate && flask db upgrade"
```

## ⚙️ Configuration avancée

### Modification de la configuration Nginx

1. Modifiez le fichier `nginx.conf`
2. Reconstruisez l'image : `docker build -t waterfall-app .`
3. Relancez le conteneur

### Ajout de variables d'environnement pour les APIs

```bash
docker run -d --name waterfall \
  -p 80:80 -p 443:443 \
  -e FLASK_ENV=development \
  -e LOG_LEVEL=debug \
  waterfall-app
```

### Persistance des données PostgreSQL

#### Avec Docker Compose (Recommandé)
```bash
# Les données sont automatiquement persistées via le volume postgres_data
docker-compose up -d
```

#### Avec Docker classique
```bash
# Avec volume Docker
docker run -d --name waterfall \
  -p 80:80 -p 443:443 \
  -v waterfall_data:/var/lib/postgresql/15/main \
  waterfall-app
```

## 📁 Structure du projet

```
waterfall-allinone/
├── Dockerfile              # Construction de l'image Docker
├── docker-compose.yml      # Configuration Docker Compose (recommandé)
├── start-all.sh            # Script d'orchestration principal
├── nginx.conf              # Configuration du reverse proxy
├── .env.example            # Exemple de variables d'environnement
└── README.md               # Cette documentation
```

## 🤝 Contribution

Pour contribuer à ce projet :
1. Clonez le repository
2. Créez une branche : `git checkout -b feature/nouvelle-fonctionnalite`
3. Commitez vos changements : `git commit -m "Ajout nouvelle fonctionnalité"`
4. Poussez vers la branche : `git push origin feature/nouvelle-fonctionnalite`
5. Ouvrez une Pull Request

## 📝 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

**🛡️ Sécurité** : Cette solution est conçue pour le développement et les environnements de test. Pour un déploiement en production, considérez l'utilisation de certificats SSL valides (Let's Encrypt) et d'une base de données externalisée.
