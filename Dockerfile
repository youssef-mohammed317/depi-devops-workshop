FROM python:3.11-slim

WORKDIR /app

# Create a non-root user and group
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser


COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt


# Copy application files and transfer ownership
COPY --chown=appuser:appgroup app/ .

# Switch to non-root user
USER appuser

COPY /app .

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD [ "python", "main.py" ]