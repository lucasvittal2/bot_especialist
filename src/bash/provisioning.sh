#!/bin/bash

build_container() {
    PYTHON_IMAGE=$1
    CONTAINER_IMAGE=$2
    echo "Building Container..."
    echo ""
    # Run the Docker build command and capture the exit code
    sudo docker build \
      --build-arg PYTHON_IMAGE=$PYTHON_IMAGE \
      -t $CONTAINER_IMAGE .

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

create_artifact_repo() {
  REPOSITORY_NAME=$1
  PROJECT_ID=$2 # Substitua pelo ID do seu projeto


  echo ""
  echo "Creating repository ${REPOSITORY_NAME}..."
  echo ""

  # Verifica se o repositório já existe
  if ! gcloud artifacts repositories list --location=us-central1 --project="$PROJECT_ID" | grep -q "$REPOSITORY_NAME"; then
    # Cria o repositório se não existir
    gcloud artifacts repositories create "$REPOSITORY_NAME" \
        --repository-format=docker \
        --location="us-central1" \
        --description="Repository to store bot specialist container image." \
        --project="$PROJECT_ID"

    created_artifact_repo=$?

    # Verifica se o repositório foi criado com sucesso
    if [ $created_artifact_repo -eq 0 ]; then
      echo "Repository ${REPOSITORY_NAME} created successfully!"
    else
      echo ""
      echo "❌ Error creating repository ${REPOSITORY_NAME}."
      echo ""
      exit 1
    fi
  else
    echo "The repository ${REPOSITORY_NAME} already exists!"
  fi
}

push_container_gcp(){
  REGISTRY_URL="$1"

  # Autentica no Google Artifact Registry, se necessário
  if ! gcloud auth configure-docker --quiet; then
    echo ""
    echo "❌ Erro ao configurar autenticação do Docker com o Google Cloud."
    echo ""
    return 1
  fi
  echo""
  echo "🚀 Enviando imagem para $REGISTRY_URL..."
  echo ""
  if docker push "$REGISTRY_URL"; then
    echo ""
    echo "✅ Imagem enviada com sucesso para $REGISTRY_URL."
    echo ""
  else
    echo ""
    echo "❌ Falha ao enviar a imagem. Verifique o erro acima."
    echo ""
    exit 1
  fi
}

provision_gcp_infra() {
  ENV=$1
  PROJECT_PATH=$(pwd)
  cd "terraform/environments/$ENV"
  echo ""
  echo "🚀 Iniciando provisionamento da infraestrutura no GCP..."
  echo ""

  # Verifica se o Terraform está instalado
  if ! command -v terraform &>/dev/null; then
    echo ""
    echo "❌ Erro: Terraform não encontrado. Instale o Terraform antes de continuar."
    echo ""
    exit 1
  fi

  # Inicializa o Terraform
  echo "🔧 Inicializando Terraform..."
  echo ""
  if ! terraform init; then
    echo ""
    echo "❌ Erro ao inicializar o Terraform."
    echo ""
    exit 1
  fi

  # Gera o plano de execução
  echo ""
  echo "📋 Gerando plano de execução..."
  echo ""
  if ! terraform plan; then
    echo ""
    echo "❌ Erro ao gerar o plano do Terraform."
    echo ""
    exit 1
  fi

  # Aplica as mudanças automaticamente
  echo ""
  echo "✅ Aplicando infraestrutura..."
  echo ""
  if ! terraform apply --auto-approve; then
    echo ""
    echo "❌ Erro ao aplicar a infraestrutura."
    echo ""
    exit 1
  fi

  echo "🎉 Infraestrutura provisionada com sucesso!"
  cd $PROJECT_PATH

}

#set params
ENV="dev"
PYTHON_CONTAINER_IMAGE="python:3.9"
CONTAINER_IMAGE="bot-specialist-$ENV:v1"
REPOSITORY_NAME="bot-specialist-repov1"
PROJECT_ID="the-bot-specialist-$ENV"
REGISTRY_URL="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${CONTAINER_IMAGE}"


build_container $PYTHON_CONTAINER_IMAGE $REGISTRY_URL
create_artifact_repo $REPOSITORY_NAME $PROJECT_ID
push_container_gcp $REGISTRY_URL $PROJECT_ID
provision_gcp_infra $ENV
