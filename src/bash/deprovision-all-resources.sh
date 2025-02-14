#!/bin/bash

# Replace with your project ID
PROJECT_ID=$1

# Set the project
gcloud config set project "$PROJECT_ID"

# Function to delete all compute instances
delete_compute_instances() {
    echo "Deleting Compute Instances..."
    gcloud compute instances list --format="value(name)" | xargs -I {} gcloud compute instances delete {} --quiet
}

# Function to delete all compute disks
delete_compute_disks() {
    echo "Deleting Compute Disks..."
    gcloud compute disks list --format="value(name)" | xargs -I {} gcloud compute disks delete {} --quiet
}

# Function to delete VPC Networks, firewalls, and routes
delete_vpc_networks() {
    echo "Deleting VPC Networks, Firewall Rules, and Routes..."
    for RULE in $(gcloud compute firewall-rules list --format="value(name)"); do
        gcloud compute firewall-rules delete $RULE --quiet
    done

    for ROUTE in $(gcloud compute routes list --format="value(name)"); do
        gcloud compute routes delete $ROUTE --quiet
    done

    gcloud compute networks list --format="value(name)" | xargs -I {} gcloud compute networks delete {} --quiet
}

# Function to delete Cloud Storage Buckets
delete_storage_buckets() {
    echo "Deleting Cloud Storage Buckets..."
    gcloud storage buckets list --format="value(name)" | xargs -I {} gcloud storage buckets delete {} --quiet
}

# Function to delete Kubernetes Engine Clusters
delete_kubernetes_clusters() {
    echo "Deleting Kubernetes Engine Clusters..."
    gcloud container clusters list --format="value(name)" | xargs -I {} gcloud container clusters delete {} --quiet
}

# Function to delete Cloud SQL instances
delete_sql_instances() {
    echo "Deleting Cloud SQL Instances..."
    gcloud sql instances list --format="value(name)" | xargs -I {} gcloud sql instances delete {} --quiet
}

# Function to delete App Engine Apps
delete_app_engine() {
    echo "Deleting App Engine App..."
    gcloud app browse --quiet
    gcloud app delete --quiet
}

# Function to delete Cloud Functions
delete_cloud_functions() {
    echo "Deleting Cloud Functions..."
    gcloud functions list --format="value(name)" | xargs -I {} gcloud functions delete {} --quiet
}

# Function to delete Pub/Sub topics
delete_pubsub_topics() {
    echo "Deleting Pub/Sub Topics..."
    gcloud pubsub topics list --format="value(name)" | xargs -I {} gcloud pubsub topics delete {} --quiet
}

# Function to delete IAM Policies and Members (if needed)
delete_iam_policies() {
    echo "Deleting IAM Policies and Members..."
    # This requires specifying the IAM members to delete manually
    # Example: gcloud projects remove-iam-policy-binding "$PROJECT_ID" --member='user:USER_EMAIL'
}

# Function to delete the entire project (optional, use with caution)
delete_project() {
    echo "Deleting the entire project..."
    gcloud projects delete "$PROJECT_ID" --quiet
}

# Run all the deprovisioning functions
delete_compute_instances
delete_compute_disks
delete_vpc_networks
delete_storage_buckets
delete_kubernetes_clusters
delete_sql_instances
delete_app_engine
delete_cloud_functions
delete_pubsub_topics
delete_iam_policies

# Uncomment the line below if you want to delete the entire project
# delete_project

echo "Deprovisioning complete."
