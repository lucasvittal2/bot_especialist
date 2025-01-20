import yaml


def read_yaml(file_path):
    with open(file_path) as file:
        data = yaml.safe_load(file)
    return data
