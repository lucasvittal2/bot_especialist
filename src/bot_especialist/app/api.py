import logging
from datetime import datetime, tzinfo

import pytz  # type: ignore
from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from langchain_google_vertexai import VertexAIEmbeddings

from bot_especialist.app.bot import OpenAIBotSpecialist
from bot_especialist.databases.sql import CloudSQL
from bot_especialist.databases.vector_store import AlloyDB
from bot_especialist.models.configs import AlloyTableConfig, BotConfig
from bot_especialist.models.connections import AlloyDBConnection, CloudSQLConnection
from bot_especialist.models.data import FeedbackRequest, QueryRequest
from bot_especialist.utils.tools import generate_hash, read_yaml

# Logging setup
for handler in logging.root.handlers[:]:
    logging.root.removeHandler(handler)

APP_NAME = "BOT-SPECIALIST"

logging.basicConfig(
    level=logging.INFO,
    format=f"%(asctime)s - [{APP_NAME}] - %(levelname)s:  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler()],
)

# Config API
APP_CONFIGS = read_yaml("configs/app-configs.yml")
bot_api = FastAPI()
bot_api.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Define API Endpoints


@bot_api.post("/bot-especialist/answer_query")
async def answer_query(request: QueryRequest):
    try:
        tz_region = APP_CONFIGS["TIME_ZONE"]
        created_at = datetime.now(tz=pytz.timezone(tz_region)).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        alloydb_connection = AlloyDBConnection(**APP_CONFIGS["CONNECTIONS"]["ALLOYDB"])
        cloud_sql_connection = CloudSQLConnection(**APP_CONFIGS["CONNECTIONS"]["TRACK"])
        cloud_sql = CloudSQL(cloud_sql_connection)
        bot_configs = BotConfig(**APP_CONFIGS["BOT"])
        embedding_model = VertexAIEmbeddings(
            model_name=APP_CONFIGS["GCP_EMBEDDING_MODEL"],
            project=APP_CONFIGS["GCP_PROJECT"],
        )
        bot_specialist = OpenAIBotSpecialist(bot_configs)
        vector_store = AlloyDB(
            connection=alloydb_connection,
            embedding_model=embedding_model,
            openai_key=APP_CONFIGS["OPENAI_API_KEY"],
        )
        async with vector_store:
            filters = " AND ".join(request.filters)
            table_config = AlloyTableConfig(**APP_CONFIGS["VECTOR_STORE"])
            await vector_store.init_vector_storage_table(
                table="bot-brain", table_config=table_config
            )
            documents = await vector_store.search_documents(request.query, filters)

        chunks = [doc.model_dump() for doc in documents]
        answer = bot_specialist.answer_question(request.query, chunks)
        dialogue_id = generate_hash(answer)
        cloud_sql.run_query(
            """
            INSERT INTO track.dialogues
            (id, user_id, created_at, question, answer)
            VALUES ('%s','%s', '%s', '%s', '%s')
            """
            % (dialogue_id, request.user_id, created_at, request.query, answer)
        )
        response = JSONResponse(
            content={"response": answer},
            status_code=status.HTTP_200_OK,
        )
    except Exception as err:
        response = JSONResponse(
            content={"error_message": "Failed to answer query, contact the support."},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
        logging.error(
            f"Answer question has failed due to: \n\n{err}\n\n", stack_info=True
        )

    return response


@bot_api.post("/bot-especialist/send_feedback")
def send_feedback(request: FeedbackRequest):
    try:
        tz_region = APP_CONFIGS["TIME_ZONE"]
        connection = CloudSQLConnection(**APP_CONFIGS["CONNECTIONS"]["TRACK"])
        cloud_sql = CloudSQL(connection)
        created_at = datetime.now(tz=pytz.timezone(tz_region)).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        user_id = request.user_id
        dialogue_id = request.dialogue_id
        feedback = request.feedback
        cloud_sql.run_query(
            """
            INSERT INTO track.feedbacks
            (user_id, dialogue_id, created_at, feedback)
            VALUES ('%s','%s' ,'%s', '%s')
            """
            % (user_id, dialogue_id, created_at, feedback)
        )

        response = JSONResponse(
            content={"message": "recorded feedback successfully"},
            status_code=status.HTTP_200_OK,
        )
    except Exception as err:
        response = JSONResponse(
            content={
                "error_message": "Failed to update metadata embeddings, contact the support."
            },
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
        logging.error(f"Answer question has failed due to: \n\n{err}\n\n")

    return response
