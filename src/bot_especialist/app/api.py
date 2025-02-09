import logging
import os
from datetime import datetime

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from langchain_google_vertexai import VertexAIEmbeddings
from pydantic import BaseModel

from bot_especialist.app.bot import OpenAIBotSpecialist
from bot_especialist.databases.sql import CloudSQL
from bot_especialist.databases.vector_store import AlloyDB
from bot_especialist.models.configs import BotConfig
from bot_especialist.models.connections import AlloyDBConnection, CloudSQLConnection
from bot_especialist.utils.tools import read_yaml

# Logging setup
for handler in logging.root.handlers[:]:
    logging.root.removeHandler(handler)

APP_NAME = os.getenv("APP_NAME")

logging.basicConfig(
    level=logging.INFO,
    format=f"%(asctime)s - [{APP_NAME}] - %(levelname)s:  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler()],
)

# Config API
APP_CONFIGS = read_yaml("app-configs.yml")
bot_api = FastAPI()
bot_api.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Define Pydantic models
class QueryRequest(BaseModel):
    query: str


class FeedbackRequest(BaseModel):
    user_id: str
    feedback: str


# Define API Endpoints


@bot_api.post("/bot-especialist/answer_query")
async def answer_query(request: QueryRequest):
    try:
        alloydb_connection = AlloyDBConnection(**APP_CONFIGS["CONNECTIONS"]["ALLOYDB"])
        bot_configs = BotConfig(**APP_CONFIGS["BOT"])
        embedding_model = VertexAIEmbeddings(
            model_name=APP_CONFIGS["GCP_EMBEDDING_MODEL"],
            project=APP_CONFIGS["GCP_PROJECT"],
        )
        vector_store = AlloyDB(
            connection=alloydb_connection, embedding_model=embedding_model
        )
        bot_specialist = OpenAIBotSpecialist(bot_configs)
        documents = await vector_store.search_documents(request.query)
        chunks = [doc.model_dump() for doc in documents]
        answer = bot_specialist.answer_question(request.query, chunks)

        response = JSONResponse(
            content={"response": answer},
            status_code=status.HTTP_200_OK,
        )
    except:
        response = JSONResponse(
            content={"error_message": "Failed to answer query, contact the support."},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return response


@bot_api.post("/items/send_feedback")
def send_feedback(request: FeedbackRequest):
    try:
        connection = CloudSQLConnection(**APP_CONFIGS["CONNECTIONS"]["FEEDBACK"])
        cloud_sql = CloudSQL(connection)
        created_at = datetime.now(tz=APP_CONFIGS["TIME_ZONE"]).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        user_id = request.user_id
        feedback = request.feedback
        cloud_sql.run_query(
            """
            INSERT INTO bot_especialist.feedbacks
            (user_id, created_at, feedback)
            VALUES (%s, %s, %s)
        """
            % (user_id, created_at, feedback)
        )

        response = JSONResponse(
            content={"message": "recorded feedback successfully"},
            status_code=status.HTTP_200_OK,
        )
    except:
        response = JSONResponse(
            content={
                "error_message": "Failed to update metadata embeddings, contact the support."
            },
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return response
