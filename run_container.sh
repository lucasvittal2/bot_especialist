#!/bin/bash


build_container() {
  echo "Building Container..."
  echo ""

  # Run the Docker build command and capture the exit code
  sudo docker build \
    --build-arg PYTHON_IMAGE=$1 \
    -t bot:v1 .

  # Check if the last command was successful
  if [ $? -eq 0 ]; then
    echo
    echo "Container was built successfully!"
    echo ""
  else
    echo
    echo "Failed to build the container. Please check the logs above for details."
    echo ""
    exit 1  # Exit the script with an error code
  fi
}

raise_container() {
  echo "Raising container..."
  echo

  IMAGE_TAG=$1
  CONTAINER_NAME=bot_api

  # Check if container exists and remove it
  if sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Found existing container '${CONTAINER_NAME}'. Stopping and removing it..."
    echo
    sudo docker stop ${CONTAINER_NAME} 2>/dev/null || true
    sudo docker rm ${CONTAINER_NAME} 2>/dev/null || true
    echo
    echo "Existed Container removed."
    echo
  fi

  # Run the Docker container
  echo "Starting new container..."
  echo

  if ! sudo docker run -p 8090:8090 --name ${CONTAINER_NAME} -d "${IMAGE_TAG}" 2>/dev/null; then
    echo "Failed to start container. Please check the logs above"
    echo
    exit 1
  fi

  echo
  echo "Container was raised successfully!"
  echo
}



#RUN
PYTHON_VERSION="python:3.9"
IMAGE_TAG="bot:v1"

build_container $PYTHON_VERSION
raise_container $IMAGE_TAG
