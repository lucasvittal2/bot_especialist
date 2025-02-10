import hashlib

import yaml


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
