FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create creditcards compatibility shim (unused import in users/forms.py)
RUN mkdir -p /usr/local/lib/python3.11/site-packages/creditcards && \
    echo "from django import forms" > /usr/local/lib/python3.11/site-packages/creditcards/__init__.py && \
    echo "from django import forms" > /usr/local/lib/python3.11/site-packages/creditcards/models.py && \
    echo "class CardNumberField(forms.CharField): pass" >> /usr/local/lib/python3.11/site-packages/creditcards/models.py && \
    echo "class CardExpiryField(forms.CharField): pass" >> /usr/local/lib/python3.11/site-packages/creditcards/models.py && \
    echo "class SecurityCodeField(forms.CharField): pass" >> /usr/local/lib/python3.11/site-packages/creditcards/models.py

# Copy application code (from submodule)
COPY ./CryptoCurrencyExchange/Exchange/ /app/

# Create media directory
RUN mkdir -p /app/media

# Expose port
EXPOSE 8000

# Run with ALLOWED_HOSTS patch and start server
CMD sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ['*']/" Exchange/settings.py && python manage.py runserver 0.0.0.0:8000
