# DEPI DevOps Workshop

A small Flask app with two endpoints, used to practice DevOps workflows.

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