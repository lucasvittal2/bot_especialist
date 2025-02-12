# 🤖 Bot Specialist

This bot is built entirely on Generative AI technology and the Retrieval-Augmented Generation (RAG) technique. Developed in the cloud, it ensures a flexible, scalable architecture while following best practices for CI/CD.

The application is designed to provide fast access to information and allows users to verify the answers it generates. Acting as a "second brain," the bot processes and stores knowledge from uploaded PDF files. Once a file is added and processed, users can ask any questions related to its content and receive accurate, AI-powered responses.

---

## ✏️ Architecture

This repository is part of the following architecture:

![System Architecture](assets/images/architecture.png)

### Components:

- **Bot API** (This repository)
- **Doc Ingestion Pipeline** (You can find it in this [link](https://github.com/lucasvittal2/doc_ingestion_pipeline/tree/dev))

The image below illustrates in more detail how the API is structured:

![Bot API Structure](assets/images/bot_api.png)

---

## 🚀 Getting Started

### 📋 Prerequisites
Before getting started, ensure you have the following prerequisites:

- Python 3.9 installed
- macOS or Linux operating system
- Google Cloud account with billing enabled
- Cloud Run and Vertex AI APIs enabled on GCP
- Terraform installed locally
- Docker installed locally
- AlloyDB public ip address of a given instance from cluster (AlloyDB> click on 3 dots in any instance > edit > Enable Public address)

### 🏃 Setup & Deployment
Once all prerequisites are met:

1. **Initialize the project**
   ```shell
   make init
   ```

2. Got to `assets/configs/app-configs-example.yml` and replace tags with your parameters, after that rename `app-configs-example.yml` to `app-configs.yml`

3. **Provision the required resources**
   ```shell
   .github/bootstrap/provisioning.sh \
     --env  <ENV> \
     --mode "CREATE" \
     --python-container-image "python:3.9" \
     --registry-repo-name  <REPOSITORY_NAME> \
     --container-image "<REGION>-docker.pkg.dev/<PROJECT_ID>/<REPOSITORY_NAME>/<IMAGE_TAG>" \
     --service-name "bot-specialist-api" \
     --container-port 8090 \
     --project-id "<PROJECT_ID>" \
     --region "<REGION>"
   ```
   ⚠️ **Don't forget to replace placeholders with your actual values.**


4. Once provisioning is complete, you will receive a URL like:
   ```text
   https://bot-api-150030916493.us-east1.run.app
   ```
   Keep this base URL safe, as you'll need it to consume the API.
5. Open file at `src/queries/create_track_tables.sql` and copy to clipboard
6.  Search for cloud SQL and click o track database:
![img.png](assets/images/cloudsqldb.png)
7. click on users Tab, then create users credentials according your preference
![img.png](assets/images/create-credentials.png)
8. Go to 'Cloud Sql Studio' tab, then use the same credentials to login:
![img.png](assets/images/studio.png)
9. Got to 'Databases' tab then Create `bot_specialist` database:
![img.png](assets/images/createdbsql.png)
10. Open a new editor then run the query inside `src/queries/create_track_tables.sql` to create track tables
![img.png](assets/images/createtracktables.png)
---

## 🌐 Consuming the API

⚠️ **This section assumes you have set up the [Doc Ingestion Pipeline](https://github.com/lucasvittal2/doc_ingestion_pipeline/tree/dev) and uploaded a document as instructed there.**

### Endpoints

#### **`POST /bot-specialist/answer_query`**
This endpoint answers user queries based on provided input and filters.

##### Request Body
```json
{
    "user_id": "<str>",
    "query": "<str>",
    "filters": ["<str>"]
}
```

##### Parameters:
- **`user_id`**: Unique user identifier in the internal system.
- **`query`**: Question asked in natural language.
- **`filters`**: A list of PostgreSQL-compatible filters, used in the `WHERE` clause. Examples:
  - `"page_number>=2"`
  - `"class IN ('type1', 'type2')"`

##### Example Request
```json
{
    "user_id": "1",
    "query": "What is Data Engineering?",
    "filters": [
        "source_doc='fundamentals-data-engineering.pdf'"
    ]
}
```

---

#### **`POST /bot-specialist/submit_feedback`**
This endpoint allows users to submit feedback on bot responses, helping improve performance.

##### Request Body
```json
{
    "user_id": "<str>",
    "feedback": "<int>",
    "dialogue_id": "<str>"
}
```

##### Parameters:
- **`user_id`**: Unique user identifier in the internal system.
- **`feedback`**: A binary field where `1` represents positive feedback and `0` represents negative feedback.
- **`dialogue_id`**: Unique identifier for a user-bot interaction.

##### Example Request
```json
{
    "user_id": "1",
    "feedback": "1",
    "dialogue_id": "113e7e86040d38e0a9f44b112fc7a0a14dfa7f2be94e4a8c30cdbc2035f25988"
}
```

---

## 🤲 Contributing

Contributions are welcome! Feel free to open issues, submit pull requests, or suggest improvements to enhance this project. 🚀
