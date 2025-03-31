# Use an official Python runtime as a parent image
FROM python:3.9-slim-buster

# Apply: https://stackoverflow.com/questions/68155641/should-i-run-things-inside-a-docker-container-as-non-root-for-safety

# Set working directory
WORKDIR /app

# Install system dependencies required for Perl (and potentially Python)
RUN apt-get update && \
    apt-get install -y --no-install-recommends perl libdbd-sqlite3-perl build-essential git openssh-client nano && \
    rm -rf /var/lib/apt/lists/*

# Copy all application files
COPY adventure_game.pl .
COPY load-and-validate-game.pl .
COPY app.py .
COPY games.cfg .
RUN mkdir static
RUN mkdir templates
COPY static/* static/
COPY templates/* templates/

# Install Python dependencies
RUN pip install flask

# Define volumes
VOLUME /app/adventures
VOLUME /app/sessions

ENV SERVICE_NAME="age"

RUN adduser --system --uid 1001 --group $SERVICE_NAME
RUN mkdir -p /var/log/$SERVICE_NAME
RUN chown $SERVICE_NAME:$SERVICE_NAME /var/log/$SERVICE_NAME
RUN chmod a+w /app

USER $SERVICE_NAME

# Command to run the application
CMD ["python", "app.py"]
