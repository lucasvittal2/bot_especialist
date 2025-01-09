ARG PYTHON_IMAGE

# First stage: Build the wheel
FROM ${PYTHON_IMAGE} AS builder

ENV APP_NAME="BOT-ESPECIALIST"
WORKDIR ./bot_especialist

# Install build tools
RUN pip install --no-cache-dir build setuptools wheel

# Copy only the specific subdirectories from the source code
COPY src/bot_especialist/app ./bot_especialist/app
COPY src/bot_especialist/databases ./bot_especialist/databases
COPY src/bot_especialist/__init__.py ./bot_especialist/__init__.py

# Copy setup.py for building the wheel
COPY README.md ./
COPY setup.py ./
COPY requirements.txt ./

# Build the distribution (sdist and wheel)
RUN python -m build

# Second stage: Final image
FROM ${PYTHON_IMAGE}

WORKDIR /bot-especialist

# Copy the built wheel from the builder stage
COPY --from=builder /bot_especialist/dist /bot_especialist/dist

# Install the built wheel
RUN pip install --no-cache-dir /bot_especialist/dist/*.whl

# Set the PYTHONPATH environment variable to point to the root module directory
ENV PYTHONPATH="/bot_especialist:${PYTHONPATH}"

# Verify installation (this ensures the module was installed correctly)
RUN python -c "import bot_especialist; print(bot_especialist.__file__)"

EXPOSE 8080
CMD ["uvicorn", "bot_especialist.app.api:bot_api", "--host", "0.0.0.0", "--port", "8080"]
