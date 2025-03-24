# Use an official Python runtime as a parent image
FROM python:3.9-slim-buster

# Set working directory
WORKDIR /app

# Install system dependencies required for Perl (and potentially Python)
RUN apt-get update && \
    apt-get install -y --no-install-recommends perl libdbd-sqlite3-perl build-essential git openssh-client && \
    rm -rf /var/lib/apt/lists/*

# Copy all application files
COPY . .

# Install Python dependencies
RUN pip install --no-cache-dir flask

# Expose port 5000 for the Flask app
EXPOSE 5000

# Define volumes
VOLUME /adventures
VOLUME /sessions

# Command to run the application
CMD ["python", "app.py"]
