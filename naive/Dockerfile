# The "it works on my machine" Dockerfile. Build it, measure it, then do better.
FROM python:3.12
COPY . .
RUN pip install -r requirements.txt
CMD uvicorn pollie.api.main:app --host 0.0.0.0 --port 8000
