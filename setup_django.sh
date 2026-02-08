#!/bin/bash

# setup_django.sh
# Automates the creation of a production-ready Django & DRF project.

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Django Project Automation Script ===${NC}"

# 1. Input Project Name
read -p "Enter project name (e.g., my_project): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Project name is required!${NC}"
    exit 1
fi

if [ -d "$PROJECT_NAME" ]; then
    echo -e "${RED}Directory '$PROJECT_NAME' already exists!${NC}"
    echo -e "${RED}Please remove it or choose a different name.${NC}"
    exit 1
fi

echo -e "${GREEN}Creating project directory: $PROJECT_NAME${NC}"
mkdir "$PROJECT_NAME"
cd "$PROJECT_NAME"

# 2. Virtual Environment Setup
echo -e "${GREEN}Creating virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# 3. Install Dependencies
echo -e "${GREEN}Installing Django, DRF, CORS-headers, and utility packages...${NC}"
pip install --upgrade pip
pip install django djangorestframework django-cors-headers python-dotenv psycopg2-binary gunicorn

# 4. Start Django Project
echo -e "${GREEN}Starting Django project...${NC}"
django-admin startproject "$PROJECT_NAME" .

# RENAME project inner directory to 'config'
echo -e "${GREEN}Renaming inner project directory to 'config'...${NC}"
mv "$PROJECT_NAME" config

# 5. Restructure Settings
echo -e "${GREEN}Restructuring settings into base, dev, and prod...${NC}"
SETTINGS_DIR="config/settings"
mkdir -p "$SETTINGS_DIR"
mv "config/settings.py" "$SETTINGS_DIR/base.py"
touch "$SETTINGS_DIR/__init__.py"

# Modify base.py to load env vars and setup CORS
echo -e "${GREEN}Configuring base settings (CORS, Env Vars)...${NC}"

# Add imports to top of base.py
sed -i '1s/^/import os\nfrom dotenv import load_dotenv\nload_dotenv(os.path.join(Path(__file__).resolve().parent.parent.parent, "envs", ".env"))\n\n/' "$SETTINGS_DIR/base.py"

# Fix BASE_DIR
# Old: BASE_DIR = Path(__file__).resolve().parent.parent
# New (inside config/settings/base.py): parent.parent.parent is the root
sed -i "s/BASE_DIR = Path(__file__).resolve().parent.parent/BASE_DIR = Path(__file__).resolve().parent.parent.parent/" "$SETTINGS_DIR/base.py"

# Fix ROOT_URLCONF and WSGI_APPLICATION uses 'config' instead of PROJECT_NAME
sed -i "s/$PROJECT_NAME.urls/config.urls/" "$SETTINGS_DIR/base.py"
sed -i "s/$PROJECT_NAME.wsgi.application/config.wsgi.application/" "$SETTINGS_DIR/base.py"

# Replace SECRET_KEY
sed -i "s/SECRET_KEY = .*/SECRET_KEY = os.getenv('SECRET_KEY')/" "$SETTINGS_DIR/base.py"

# Replace DEBUG
sed -i "s/DEBUG = .*/DEBUG = os.getenv('DEBUG') == 'True'/" "$SETTINGS_DIR/base.py"

# Replace ALLOWED_HOSTS
sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost').split(',')/" "$SETTINGS_DIR/base.py"

# Add Apps
sed -i "/'django.contrib.staticfiles',/a \    'rest_framework',\n    'corsheaders',\n    'common'," "$SETTINGS_DIR/base.py"

# Add Middleware
sed -i "/'django.middleware.common.CommonMiddleware',/i \    'corsheaders.middleware.CorsMiddleware'," "$SETTINGS_DIR/base.py"

# Setup CORS defaults
echo "" >> "$SETTINGS_DIR/base.py"
echo "# CORS Setup" >> "$SETTINGS_DIR/base.py"
echo "CORS_ALLOW_ALL_ORIGINS = os.getenv('CORS_ALLOW_ALL_ORIGINS') == 'True'" >> "$SETTINGS_DIR/base.py"
echo "CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', '').split(',') if not CORS_ALLOW_ALL_ORIGINS else []" >> "$SETTINGS_DIR/base.py"

# Create dev.py
cat <<EOF > "$SETTINGS_DIR/dev.py"
from .base import *

DEBUG = True
ALLOWED_HOSTS = ['*']
CORS_ALLOW_ALL_ORIGINS = True

# Database (Default to SQLite for dev, can be overridden)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
EOF

# Create prod.py
cat <<EOF > "$SETTINGS_DIR/prod.py"
from .base import *
import os

DEBUG = False
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '').split(',')

# Production Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DATABASE_NAME'),
        'USER': os.getenv('DATABASE_USER'),
        'HOST': os.getenv('DATABASE_HOST'),
        'PORT': os.getenv('DATABASE_PORT'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD'),
    }
}
EOF

# 6. Create Apps, Envs, Common and Logs Directories
echo -e "${GREEN}Creating 'apps', 'common', 'envs', and 'logs' directories...${NC}"
mkdir apps
touch apps/__init__.py
mkdir common
touch common/__init__.py
mkdir envs
mkdir logs
touch logs/.gitkeep

# Register apps and common dir in base.py
echo "" >> "$SETTINGS_DIR/base.py"
echo "import sys" >> "$SETTINGS_DIR/base.py"
echo "sys.path.insert(0, os.path.join(BASE_DIR, 'apps'))" >> "$SETTINGS_DIR/base.py"

# 7. Create .env files
echo -e "${GREEN}Generating environment files in envs/...${NC}"
cat <<EOF > envs/.env
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ALLOW_ALL_ORIGINS=True
DATABASE_NAME=$PROJECT_NAME
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_HOST=db
DATABASE_PORT=5432
EOF
cp envs/.env envs/.env.example

# 8. Update manage.py and wsgi.py/asgi.py to use new settings
echo -e "${GREEN}Updating manage.py and wsgi entry points...${NC}"
# Correct path: manage.py is in current dir, settings are now in config.settings
sed -i "s/$PROJECT_NAME.settings/config.settings.dev/" manage.py
sed -i "s/$PROJECT_NAME.settings/config.settings.prod/" "config/wsgi.py"
sed -i "s/$PROJECT_NAME.settings/config.settings.prod/" "config/asgi.py"

# 9. Docker Setup
echo -e "${GREEN}Generating Docker configuration...${NC}"

# Dockerfile
cat <<EOF > Dockerfile
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "config.wsgi:application"]
EOF

# docker-compose.yml (Local Dev)
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    env_file:
      - envs/.env
    depends_on:
      - db

  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=$PROJECT_NAME
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres

volumes:
  postgres_data:
EOF

# docker-compose.prod.yml
cat <<EOF > docker-compose.prod.yml
version: '3.8'

services:
  web:
    build: .
    restart: always
    command: gunicorn --bind 0.0.0.0:8000 config.wsgi:application
    volumes:
      - static_volume:/app/static
      - media_volume:/app/media
    env_file:
      - envs/.env
    depends_on:
      - db

  db:
    image: postgres:15
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=$PROJECT_NAME
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres

volumes:
  postgres_data:
  static_volume:
  media_volume:
EOF

# 10. Final Requirements
pip freeze > requirements.txt

echo -e "${BLUE}=== Setup Complete! ===${NC}"
echo -e "Project '$PROJECT_NAME' created successfully."
echo -e "The inner configuration folder is named 'config' and a 'common' app has been added."
echo -e "Make sure to delete any failed previous attempts folder if you had to re-run."
echo -e "To get started:"
echo -e "  cd $PROJECT_NAME"
echo -e "  source venv/bin/activate"
echo -e "  python manage.py migrate"
echo -e "  python manage.py runserver"
echo -e "${GREEN}Happy Coding!${NC}"
