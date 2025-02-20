#!/bin/bash

set -e
build_container() {
    PYTHON_IMAGE=$1
    CONTAINER_IMAGE=$2
    PORT=$3
    ENV=$4
    echo "Building Container..."
    echo ""
    # Run the Docker build command and capture the exit code
    docker build \
      --build-arg PYTHON_IMAGE="$PYTHON_IMAGE" \
      --build-arg PORT="$PORT" \
      --build-arg GCP_PROJECT="the-bot-specialist-${ENV}" \
      -t "$CONTAINER_IMAGE" .

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
      echo "✅ Repository ${REPOSITORY_NAME} created successfully!"
    else
      echo ""
      echo "❌ Error creating repository ${REPOSITORY_NAME}."
      echo ""
      exit 1
    fi
  else
    echo "⚠️ The repository ${REPOSITORY_NAME} already exists! Not created this repository again."
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
  echo "🚀 Pushing image to $REGISTRY_URL..."
  echo ""
  if docker push "$REGISTRY_URL"; then
    echo ""
    echo "🐋 Image pushed successfully to $REGISTRY_URL."
    echo ""
  else
    echo ""
    echo "❌ Failed to push image to $REGISTRY_URL. Check logs above ! "
    echo ""
    exit 1
  fi
}

provision_gcp_infra() {
  ENV=$1
  PROJECT_PATH=$(pwd)

  
  if [ "$ENV" = "prod"]; then
    INFRA_ENV="production"
  elif [ "$ENV" = "stage"]; then
    INFRA_ENV="staging"
  else
    INFRA_ENV="dev"
  fi

  cd "terraform/environments/$ENV"
  echo "$(pwd)"
  echo ""
  echo "🚀 Startig provisioning GCP infrastructure..."
  echo ""

  # Verifica se o Terraform está instalado
  if ! command -v terraform &>/dev/null; then
    echo ""
    echo "❌ Error terraform not found. Install terraform before starting this script !"
    echo ""
    exit 1
  fi

  # Inicializa o Terraform
  echo "🔧 Starting Terraform..."
  echo ""
  if ! terraform init; then
    echo ""
    echo "❌ Error on starting Terraform."
    echo ""
    exit 1
  fi

  # Gera o plano de execução
  echo ""
  echo "📋 Generating Execution plan..."
  echo ""
  if ! terraform plan -var-file="terraform/environments/$INFRA_ENV/terraform.tfvars"; then
    echo ""
    echo "❌ Got error on planning execution on terraform."
    echo ""
    exit 1
  fi

  # Aplica as mudanças automaticamente
  echo ""
  echo "✅  Applying infrastructure..."
  echo ""
  if ! terraform apply --auto-approve -var-file="terraform/environments/$INFRA_ENV/terraform.tfvars"; then
    echo ""
    echo "❌ Got error when applying the infrastructure."
    echo ""
    exit 1
  fi

  echo "🎉 GCP Infrastructure provisioned successfully !"
  cd $PROJECT_PATH

}

destroy_gcp_infra(){
  ENV=$1
  PROJECT_PATH=$(pwd)
  cd "terraform/environments/$ENV"
  echo "$(pwd)"
  echo "🔥 Destroying all provisioned GCP infrastructure..."
  echo ""
  terraform destroy --auto-approve
  ret=$?
  if [ $ret -ne 0 ]; then
    echo ""
    echo "❌  Error when trying to destroy GCP infrastructure"
    echo ""
    exit 1
  fi
  echo "💥 Destroyed Successfully GCP infrastructure"
  cd $PROJECT_PATH
}

deploy_container() {
  if [ $# -ne 5 ]; then
    echo "❌ Uso: deploy_container <IMAGE_URL> <LISTEN_PORT> <SERVICE_NAME> <REGION> <ENV>"
    return 1
  fi

  local IMAGE_URL="$1"
  local LISTEN_PORT="$2"
  local SERVICE_NAME="$3"
  local REGION="$4"
  local ENV=$5

  SERVICE_ACCOUNT="${ENV}-108@the-bot-specialist-dev.iam.gserviceaccount.com"


  echo ""
  echo "📦 🐳 Deploying container '$SERVICE_NAME' to Cloud Run in region '$REGION'..."
  echo ""

  if gcloud run deploy "$SERVICE_NAME" --image="$IMAGE_URL" --port="$LISTEN_PORT" --region="$REGION" --service-account "$SERVICE_ACCOUNT"; then
    echo ""
    echo "✅  🚢  Container '$SERVICE_NAME' was successfully deployed in '$REGION'!"
    echo ""
  else
    echo "❌ 🚨 Deployment failed. Check logs for details."
    return 1
  fi
}

# shellcheck disable=SC2120


# Inicializa variáveis
echo "running script with the following parameters:"
echo ""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --env)
    ENV="$2"
    echo "ENV=$ENV"
    shift 2
    ;;
  --mode)
    MODE="$2"
    echo "MODE=$MODE"
    shift 2
    ;;
  --python-container-image)
    PYTHON_CONTAINER_IMAGE="$2"
    echo "PYTHON_CONTAINER_IMAGE=$PYTHON_CONTAINER_IMAGE"
    shift 2
    ;;
  --registry-repo-name)
    REPOSITORY_NAME="$2"
    echo "REPOSITORY_NAME=$REPOSITORY_NAME"
    shift 2
    ;;
  --service-name)
    SERVICE_NAME="$2"
    echo "CONTAINER_IMAGE=$CONTAINER_IMAGE"
    shift 2
    ;;
  --container-image)
    CONTAINER_IMAGE="$2"
    echo "CONTAINER_IMAGE=$CONTAINER_IMAGE"
    shift 2
    ;;
  --container-port)
    CONTAINER_PORT="$2"
    echo "CONTAINER_PORT $CONTAINER_PORT"
    shift 2
    ;;
  --project-id)
    PROJECT_ID="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  --region)
    REGION="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  *)
    echo "❌ Invalid option: $1"
    usage
    ;;
esac
done

# Main execution
if [ "$MODE" = "CREATE" ]; then
  ## Verifica se todas as variáveis obrigatórias foram definidas
  if [[ -z "$ENV" || -z "$MODE" || -z "$PYTHON_CONTAINER_IMAGE" || -z "$REPOSITORY_NAME" || -z "$CONTAINER_IMAGE" || -z "$PROJECT_ID" ]]; then
    echo "❌ Erro: Todos os parâmetros são obrigatórios!"
    usage
  fi

  REGISTRY_URL="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${CONTAINER_IMAGE}"
  build_container "$PYTHON_CONTAINER_IMAGE" "$REGISTRY_URL" "$CONTAINER_PORT" "$ENV"
  create_artifact_repo "$REPOSITORY_NAME" "$PROJECT_ID"
  push_container_gcp "$REGISTRY_URL" "$PROJECT_ID"
  provision_gcp_infra "$ENV"
  deploy_container "$REGISTRY_URL" "$CONTAINER_PORT" "$SERVICE_NAME" "$REGION" "$ENV"

fi

if [ "$MODE" = "DESTROY" ]; then
  destroy_gcp_infra "dev"
fi
