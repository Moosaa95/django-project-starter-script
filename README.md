# 🚀 Django & DRF Production Setup Script

Stop setting up Django projects from scratch! This script automates the tedious boilerplate work so you can jump straight into building features.

It sets up a **production-ready** Django + Django REST Framework project with a modular structure, Docker support, and best practices baked in.

## ✨ Features at a Glance

*   **Modular Settings**: Split settings for `base`, `dev`, and `prod`. No more messy `if DEBUG:` checks.
*   **Clean Structure**:
    *   `config/`: Your project configuration (settings, urls, wsgi). Renamed from project name to keep imports generic.
    *   `apps/`: A dedicated folder for all your Django apps.
    *   `common/`: A place for shared utilities, mixins, and helpers.
    *   `envs/`: Environment variables live here, away from your code.
*   **Ready-to-Go Stack**:
    *   **Django REST Framework** installed.
    *   **CORS Headers** configured based on environment variables.
    *   **Gunicorn** for production serving.
    *   **PostgreSQL** adapter (`psycopg2-binary`) included.
*   **Dockerized**: Auto-generates `Dockerfile` and `docker-compose` files for both local dev and production.
*   **Security First**: Generates a unique `SECRET_KEY` and sets up `python-dotenv` to load secrets securely.

## 🛠️ Quick Start

1.  **Download the script** to the folder where you want your project to live.
2.  **Make it executable**:
    ```bash
    chmod +x setup_django.sh
    ```
3.  **Run it**:
    ```bash
    ./setup_django.sh
    ```
4.  **Follow the prompt**: Enter your desired project name (e.g., `my_awesome_api`).

### What happens next?
The script will create a folder named `my_awesome_api`, set up a virtual environment, install dependencies, and restructure everything for you.

To start the dev server immediately:
```bash
cd my_awesome_api
source venv/bin/activate
python manage.py migrate
python manage.py runserver
```

## 🐳 Docker Usage

Don't want to install Python locally? Use Docker!

**Development:**
```bash
docker-compose up --build
```
This spins up your Django app and a Postgres database. The app volume is mounted so code changes reflect instantly.

**Production:**
```bash
docker-compose -f docker-compose.prod.yml up --build -d
```
Uses `gunicorn`, serves static files properly (you'll need to configure Nginx/Traefik in front), and restarts on failure.

## 📂 Project Structure Explained

```text
my_project/
├── apps/               # Put your Django apps here (e.g., users, payments)
├── common/             # Shared code (utils, custom exceptions)
├── config/             # Django project configuration
│   ├── settings/
│   │   ├── base.py     # Common settings (apps, middleware)
│   │   ├── dev.py      # Dev settings (Debug=True, SQLite default)
│   │   └── prod.py     # Prod settings (Debug=False, Postgres)
│   ├── urls.py
│   └── wsgi.py
├── envs/               # Environment variables
│   ├── .env            # SENSITIVE! Ignored by git (if you set up .gitignore)
│   └── .env.example    # Safe to commit
├── logs/               # Log files directory
├── manage.py
├── Dockerfile
└── docker-compose.yml
```

## ⚙️ Configuration

Check `envs/.env` to tweak your settings:
*   `DEBUG`: Set to `True` or `False`.
*   `ALLOWED_HOSTS`: Comma-separated list of domains.
*   `CORS_ALLOWED_ORIGINS`: Comma-separated list of frontend URLs (e.g., `http://localhost:3000`).
*   `DATABASE_...`: Your Postgres credentials.

Enjoy building! 🚀
