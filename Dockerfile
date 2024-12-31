# [*CAUTION*] BEAM AND PYTHON VERSIONS SHOULD MATCH COMPOSER 2 IMAGE VERSION.
ARG BEAM_IMAGE
ARG BEAM_VERSION
ARG BEAM_IMAGE_VERSION=${BEAM_IMAGE}:${BEAM_VERSION}

# First stage: Build the wheel
FROM ${BEAM_IMAGE_VERSION} AS builder

ARG BEAM_VERSION
ENV PYTHONUNBUFFERED=1
WORKDIR /bot-especialist

# Copy only the specific subdirectories from the source code
COPY src/bot_especialist/beam ./bot-especialist/App
COPY src/bot_especialist/llms ./bot-especialist/databases
COPY src/bot_especialist/__init__.py ./bot-especialist/__init__.py

# Copy setup.py for building the wheel
COPY README.md ./
COPY setup.py ./
COPY requirements.txt ./

# Build the distribution (sdist and wheel)
RUN python -m build

# Second stage: Final image
FROM ${BEAM_IMAGE_VERSION}

WORKDIR /bot-especialist

# Copy the built wheel and prompt from the builder stage
COPY --from=builder /bot-especialist/dist /bot-especialist/dist

# Install the built wheel
RUN pip install --no-cache-dir /bot_especialist/dist/*.whl

# Set the PYTHONPATH environment variable to point to the root module directory
ENV PYTHONPATH="/bot-especialist:${PYTHONPATH}"

# Verify installation (this ensures the module was installed correctly)
RUN python -c "import bot-especialist; print(bot-especialist.__file__)"

# Set the entrypoint for the container
ENTRYPOINT ["/opt/apache/beam/boot"]
