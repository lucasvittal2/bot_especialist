#!/bin/bash

set -e
build_container() {
    PYTHON_IMAGE=$1
    CONTAINER_IMAGE=$2
    PORT=$3
    ENV=$4
    echo "⚙️ Building Container..."
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
      echo "✅ Container was built successfully!"
      echo ""
    else
      echo
      echo "❌ Failed to build the container. Please check the logs above for details."
      echo ""
      exit 1  # Exit the script with an error code
    fi
}

create_artifact_repo() {
  REPOSITORY_NAME=$1
  PROJECT_ID=$2 # Substitua pelo ID do seu projeto


  echo ""
  echo "⚙️ Creating repository ${REPOSITORY_NAME}..."
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
  echo ""
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
  cd "terraform/environment"
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
  if ! terraform apply --auto-approve; then
    echo ""
    echo "❌ Got error on planning execution on terraform."
    echo ""
    exit 1
  fi

  # Aplica as mudanças automaticamente
  echo ""
  echo "⚙️  Applying infrastructure..."
  echo ""
  if ! terraform apply --auto-approve; then
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
  cd "terraform/environment"
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
enable_necessary_apis(){
  echo ""
  echo "⚙️ Enabling required APIs..."
  gcloud services enable container.googleapis.com
  gcloud services enable iam.googleapis.com
  gcloud services enable artifactregistry.googleapis.com
  echo "✅ All needed API is enabled !"
  echo ""
}

create_gke_sa(){
  SERVICE_ACCOUNT_NAME=$1
  PROJECT_ID=$2
  echo ""
  echo "⚙️ Creating gke Service Account..."
  if gcloud iam service-accounts list --format="value(email)" | grep -q "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"; then
      echo "⚠️ Service Account '$SERVICE_ACCOUNT_NAME' already exists."
      echo ""
  else
      echo "👤 Creating Service Account: $SERVICE_ACCOUNT_NAME"
      gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
          --display-name "GKE Service Account"
      gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@the-bot-specialist-dev.iam.gserviceaccount.com" \
      --role="roles/artifactregistry.reader"

      echo "🔑 Assigning IAM roles to Service Account..."
      gcloud projects add-iam-policy-binding "$PROJECT_ID" \
          --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
          --role="roles/container.admin"
      echo "✅ Service Account were created successfully !"
      echo ""
  fi

}

create_gke_subnet(){
    NETWORK=$1
    GKE_SUBNETWORK=$2
    REGION=$3
    echo "⚙️ Creating GKE subnet..."
    if gcloud compute networks subnets list --filter="name=$GKE_SUBNETWORK AND region=$REGION" --format="value(name)"; then
        echo "⚠️  Subnetwork '$GKE_SUBNETWORK' already exists. Skipping GKE subnet creation..."
        echo ""
    else
        echo "🌐 Creating subnetwork '$GKE_SUBNETWORK' in network '$NETWORK' ..."
        gcloud compute networks subnets create "$GKE_SUBNETWORK" \
            --network="$NETWORK" \
            --region="$REGION" \
            --range="10.0.0.0/20"
        echo "✅ GKE subnet were created successfully !"
        echo ""
    fi
  }

create_gke_cluster(){
    CLUSTER_NAME=$1
    REGION=$2
    SERVICE_ACCOUNT=$3
    GKE_SUBNETWORK=$4
    GKE_DISK_SIZE=$5
    GKE_MIN_NODES=$6
    GKE_MAX_NODES=$7

    CREATED_CLUSTER=$(gcloud container clusters list --filter="name=$CLUSTER_NAME AND location=$REGION" --format="value(name)")
    echo "⚙️ Creating GKE cluster..."
    if [[ -n "$CREATED_CLUSTER" ]]; then
        echo "⚠️ GKE Cluster '$CLUSTER_NAME' already exists. Skipping creation..."
        echo ""
    else
        echo "🚀 Creating GKE Cluster: $CLUSTER_NAME..."
        gcloud container clusters create "$CLUSTER_NAME" \
            --num-nodes=1 \
            --machine-type="e2-medium" \
            --service-account="$SERVICE_ACCOUNT" \
            --scopes="https://www.googleapis.com/auth/cloud-platform" \
            --region="$REGION" \
            --disk-size="$GKE_DISK_SIZE" \
            --enable-autoscaling \
            --min-nodes="$GKE_MIN_NODES" \
            --max-nodes="$GKE_MAX_NODES" \
            --subnetwork="$GKE_SUBNETWORK"
        echo "✅ GKE cluster were created successfully !"
        echo ""
    fi
}

setup_cluster_credentials(){
  CLUSTER_NAME=$1
  K8S_SERVICE_ACCOUNT=$2
  REGION=$3
  PROJECT_ID=$4

  echo "🔄 Fetching cluster credentials..."
  gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION"
  if kubectl get serviceaccount "$K8S_SERVICE_ACCOUNT" --output=jsonpath='{.metadata.name}'; then
      echo "⚠️ Kubernetes Service Account '$K8S_SERVICE_ACCOUNT' already exists. Skipping creation..."
      echo ""

  else
      echo "🔧 Creating Kubernetes Service Account: $K8S_SERVICE_ACCOUNT..."
      kubectl create serviceaccount "$K8S_SERVICE_ACCOUNT"
      gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:${K8S_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role="roles/artifactregistry.reader"
      gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${K8S_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/alloydb.client"
      gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${K8S_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/serviceusage.serviceUsageConsumer"
      echo "✅ Kubernetes service account created successfully !"
      echo ""

  fi
  echo "🔗 Binding Kubernetes SA to GCP IAM..."

  gcloud iam service-accounts add-iam-policy-binding "$K8S_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/$K8S_SERVICE_ACCOUNT]"

  kubectl annotate serviceaccount "$K8S_SERVICE_ACCOUNT" \
      iam.gke.io/gcp-service-account="$K8S_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
  echo "✅ Cluster credentials setup completed successfully !"
  echo ""
}
deploy_container() {
  if [ $# -ne 10 ]; then
    echo "❌ Uso: deploy_container <IMAGE_URL> <LISTEN_PORT> <SERVICE_NAME> <REGION> <ENV> <PROJECT_ID>"
    return 1
  fi

  local IMAGE_URL="$1"
  local LISTEN_PORT="$2"
  local SERVICE_NAME="$3"
  local REGION="$4"
  local ENV=$5
  local PROJECT_ID=$6
  local GKE_DISK_SIZE=$7
  local GKE_MIN_NODES=$8
  local GKE_MAX_NODES=$9
  local GKE_NODE_MACHINE_TYPE=${10}
  echo

  NETWORK='default'
  SERVICE_ACCOUNT_NAME="gke-${ENV}"
  SERVICE_ACCOUNT="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
  DEPLOYMENT_FILE="assets/kubernetes/deployment.yaml"
  CLUSTER_NAME="bot-api-cluster-${ENV}"
  K8S_SERVICE_ACCOUNT="gke-sa-${ENV}"
  GKE_SUBNETWORK="gke-net-${ENV}"
  DEPLOYMENT_NAME="bot-specialist-api"


  enable_necessary_apis
  create_gke_sa "$SERVICE_ACCOUNT_NAME" "$PROJECT_ID"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$SERVICE_ACCOUNT" \
      --role="roles/storage.admin"

  create_gke_subnet "$NETWORK" "$GKE_SUBNETWORK" "$REGION"
  create_gke_cluster  "$CLUSTER_NAME" "$REGION" "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" "$GKE_SUBNETWORK" "$GKE_DISK_SIZE" "$GKE_MIN_NODES" "$GKE_MAX_NODES"
  setup_cluster_credentials "$CLUSTER_NAME" "$SERVICE_ACCOUNT_NAME" "$REGION" "$PROJECT_ID"


  echo "📌 Deploying application to GKE..."
  kubectl apply -f "$DEPLOYMENT_FILE"
  EXISTING_SERVICE=$(kubectl get svc "$DEPLOYMENT_NAME" --ignore-not-found)

  if [[ -n "$EXISTING_SERVICE" ]]; then
      echo "⚠️ Service '$DEPLOYMENT_NAME' already exists. Skipping expose..."
      echo ""
  else
      echo "🌐 Exposing the application via LoadBalancer..."
      kubectl expose deployment "$DEPLOYMENT_NAME" --type=LoadBalancer --port="80" --target-port="8090"
      echo "✔️ Application is exposed via LoadBalancer"
      echo ""
  fi


  echo "⏳ Waiting for external IP..."
  sleep 10  # Initial wait time
  while true; do
      EXTERNAL_IP=$(kubectl get "svc/$DEPLOYMENT_NAME" --output=jsonpath='{.status.loadBalancer.ingress[0].ip}')
      if [[ -n "$EXTERNAL_IP" ]]; then
          echo "🎉 Application is live at: http://${EXTERNAL_IP}:80"
          break
      else
          echo "⌛ Still waiting for external IP..."
          sleep 10
      fi
  done
  echo "✅ Deployment process completed successfully!"
  echo ""

}


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
    echo "CONTAINER_IMAGE=$SERVICE_NAME"
    shift 2
    ;;
  --container-image)
    CONTAINER_IMAGE="$2"
    echo "CONTAINER_IMAGE=$CONTAINER_IMAGE"
    shift 2
    ;;
  --container-port)
    CONTAINER_PORT="$2"
    echo "CONTAINER_PORT=$CONTAINER_PORT"
    shift 2
    ;;
  --project-id)
    PROJECT_ID="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  --region)
    REGION="$2"
    echo "REGION=$REGION"
    shift 2
    ;;
  --gke-disk-size)
    GKE_DISK_SIZE="$2"
    echo "GKE_DISK_SIZE=$GKE_DISK_SIZE"
    shift 2
    ;;
  --gke-min-nodes)
    GKE_MIN_NODES="$2"
    echo "GKE_MIN_NODES=$GKE_MIN_NODES"
    shift 2
    ;;
  --gke-max-nodes)
    GKE_MAX_NODES="$2"
    echo "GKE_MAX_NODES=$GKE_MAX_NODES"
    shift 2
    ;;
  --gke-node-machine-type)
    GKE_NODE_MACHINE_TYPE="$2"
    echo "PROJECT_ID=$GKE_NODE_MACHINE_TYPE"
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
  # shellcheck disable=SC1019
  # shellcheck disable=SC1072
  if [[ -z "$ENV" || -z "$MODE" || -z "$PYTHON_CONTAINER_IMAGE" || -z "$REPOSITORY_NAME" || -z "$CONTAINER_IMAGE" || -z "$PROJECT_ID" || -z "$GKE_DISK_SIZE" || -z "$GKE_MIN_NODES"  || -z "$GKE_NODE_MACHINE_TYPE" ]]; then
    echo "❌ Erro: Todos os parâmetros são obrigatórios!"
    usage
  fi

  ## SET vars
  export TF_VAR_project_name="$PROJECT_ID"
  export TF_VAR_region="$REGION"
  export TF_VAR_registry_repo_name="$REPOSITORY_NAME"
  REGISTRY_URL="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${CONTAINER_IMAGE}"

  ## Run Provision pipeline
  build_container "$PYTHON_CONTAINER_IMAGE" "$REGISTRY_URL" "$CONTAINER_PORT" "$ENV"
  create_artifact_repo "$REPOSITORY_NAME" "$PROJECT_ID"
  push_container_gcp "$REGISTRY_URL" "$PROJECT_ID"
  #provision_gcp_infra "$ENV"
  deploy_container "$REGISTRY_URL" \
                    "$CONTAINER_PORT" \
                    "$SERVICE_NAME" \
                    "$REGION" \
                    "$ENV" \
                    "$PROJECT_ID" \
                    "$GKE_DISK_SIZE" \
                    "$GKE_MIN_NODES" \
                    "$GKE_MAX_NODES" \
                    "$GKE_NODE_MACHINE_TYPE"


fi

if [ "$MODE" = "DESTROY" ]; then

  destroy_gcp_infra "dev"
fi
