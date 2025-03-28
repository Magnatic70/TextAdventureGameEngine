# Use an official Python runtime as a parent image
FROM python:3.9-slim-buster

# Set working directory
WORKDIR /app

# Install system dependencies required for Perl (and potentially Python)
RUN apt-get update && \
    apt-get install -y --no-install-recommends perl libdbd-sqlite3-perl build-essential git openssh-client && \
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

# Command to run the application
CMD ["python", "app.py"]
