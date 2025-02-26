# Define build arguments
ARG PYTHON_IMAGE
ARG GCP_PROJECT
ARG PORT

# First stage: Build the wheel
FROM ${PYTHON_IMAGE} AS builder

ENV APP_NAME="BOT-ESPECIALIST"
WORKDIR /bot_especialist

# Install build tools
RUN pip install --no-cache-dir build setuptools wheel

# Copy specific subdirectories from the source code
COPY src/bot_especialist/app ./bot_especialist/app
COPY src/bot_especialist/databases ./bot_especialist/databases
COPY src/bot_especialist/models ./bot_especialist/models
COPY src/bot_especialist/utils ./bot_especialist/utils
COPY src/bot_especialist/__init__.py ./bot_especialist/__init__.py

# Copy setup.py for building the wheel
COPY README.md ./
COPY src/setup.py ./
COPY requirements.txt ./

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir build setuptools wheel

# Build the distribution
RUN python setup.py sdist bdist_wheel

# Second stage: Final image
FROM ${PYTHON_IMAGE}

WORKDIR /bot-especialist

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y google-cloud-sdk

# Verify gcloud installation
RUN gcloud --version

# Convert ARG to ENV to make it accessible during build time
ARG GCP_PROJECT
ENV GCP_PROJECT=${GCP_PROJECT}

# Debugging to ensure the value is set
RUN echo "GCP_PROJECT is set to: $GCP_PROJECT"

# Set GCP project (now works because it's ENV)
RUN gcloud config set project "$GCP_PROJECT"

# Copy the built wheel from the builder stage
COPY --from=builder /bot_especialist/dist /bot_especialist/dist

# Copy Config File
COPY assets/configs/app-configs.yaml configs/app-configs.yaml

# Install the built wheel
RUN pip install -U langchain-community
RUN pip install --no-cache-dir /bot_especialist/dist/*.whl

# Set the PYTHONPATH environment variable
ENV PYTHONPATH="/bot_especialist:${PYTHONPATH}"

# Verify installation
RUN python -c "import bot_especialist; print(bot_especialist.__file__)"

EXPOSE 8090
CMD ["sh", "-c", "uvicorn bot_especialist.app.api:bot_api --host 0.0.0.0 --port $PORT"]
