FROM python:3.11-slim

WORKDIR /app

#Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

#Copy requirements first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

#Copy the app folder
COPY app/ ./app/

#Copy .env if exits
#COPY .env* . 2>/dev/null || true

EXPOSE 8000

#Set default SQLite for container
ENV DATABASE_URL=sqlite:///./aiot.db

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
