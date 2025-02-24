import hashlib

import yaml
from google.cloud import secretmanager


def read_yaml(file_path):
    with open(file_path) as file:
        data = yaml.safe_load(file)
    return data


def generate_hash(text, algorithm="sha256"):
    hash_func = getattr(hashlib, algorithm, None)
    if hash_func is None:
        raise ValueError(f"Unsupported hashing algorithm: {algorithm}")

    hash_object = hash_func(text.encode())
    return hash_object.hexdigest()


def get_gcp_secrets(project_id: str, secret_id: str, version_id="latest"):

    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    response = client.access_secret_version(name=name)
    gcp_secrets = yaml.safe_load(response.payload.data.decode("UTF-8"))
    return gcp_secrets


print(get_gcp_secrets("150030916493", "bot-api-secrets"))
