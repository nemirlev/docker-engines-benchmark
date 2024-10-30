# Multi-stage build for ML application
FROM python:3.9 as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    software-properties-common \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create requirements.txt
RUN echo 'tensorflow==2.13.0' > requirements.txt && \
    echo 'torch==2.0.1' >> requirements.txt && \
    echo 'transformers==4.31.0' >> requirements.txt && \
    echo 'scipy==1.11.2' >> requirements.txt && \
    echo 'scikit-learn==1.3.0' >> requirements.txt && \
    echo 'pandas==2.0.3' >> requirements.txt && \
    echo 'numpy==1.24.3' >> requirements.txt && \
    echo 'matplotlib==3.7.2' >> requirements.txt && \
    echo 'seaborn==0.12.2' >> requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create sample ML application
COPY . .
RUN echo 'import tensorflow as tf' > app.py && \
    echo 'import torch' >> app.py && \
    echo 'import transformers' >> app.py && \
    echo 'from sklearn.ensemble import RandomForestClassifier' >> app.py && \
    echo 'import numpy as np' >> app.py && \
    echo 'import pandas as pd' >> app.py && \
    echo 'print("TensorFlow version:", tf.__version__)' >> app.py && \
    echo 'print("PyTorch version:", torch.__version__)' >> app.py && \
    echo 'print("Transformers version:", transformers.__version__)' >> app.py

FROM python:3.9-slim

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/app.py .
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages

CMD ["python", "app.py"]
