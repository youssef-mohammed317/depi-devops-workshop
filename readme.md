# DEPI DevOps Workshop

A small Flask app with two endpoints, used to practice DevOps workflows: testing, Docker, and Docker Compose.

## Project structure

```
DEPI-DEVOPS-WORKSHOP/
├── .github/
│   ├── workflows/
│   └── pull_request_template.md
├── ansible/
├── app/
│   └── main.py
├── infra/
├── tests/
│   └── test_app.py
├── .dockerignore
├── .gitignore
├── docker-compose.yml
├── Dockerfile
├── README.md
└── requirements.txt
```

## Endpoints

- `GET /` returns a welcome message
- `GET /health` returns the health status

## Run locally

```bash
pip install -r requirements.txt
python app/main.py
```

Then open http://localhost:5000

## Run tests

```bash
python -m pytest tests/
```

## Run with Docker

Build the image:

```bash
docker build -t depi-flask-app .
```

Run the container:

```bash
docker run -p 5001:5000 depi-flask-app
```

Then open http://localhost:5001

Docker details:

- The container runs as a non-root user (`appuser`).
- The image has a `HEALTHCHECK` that calls `/health`.
- `.dockerignore` keeps tests, caches and Git files out of the image.

## Run with Docker Compose

Start the app in the background:

```bash
docker compose up -d --build
```

Check that the container is healthy:

```bash
docker compose ps
```

Stop everything:

```bash
docker compose down
```

The Compose file sets a restart policy (`unless-stopped`), maps port 5001 to 5000, and defines a healthcheck.

## Contributing

- Open a Pull Request for every change. A PR template is filled in automatically.
- Run the tests before opening the PR.
- The `main` branch is protected, so direct pushes are blocked.