import logging

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from bot_especialist.app.bot import OpenAIBotSpecialist
from bot_especialist.models.configs import BotConfig
from bot_especialist.models.data import FeedbackRequest, QueryRequest
from bot_especialist.utils.app_logging import LoggerHandler
from bot_especialist.utils.tools import get_gcp_secrets

# Logging setup
for handler in logging.root.handlers[:]:
    logging.root.removeHandler(handler)

APP_NAME = "BOT-SPECIALIST"
logger = LoggerHandler(
    logger_name=APP_NAME, logging_type="gcp_console", log_level="INFO"
).get_logger()

# Config API
APP_CONFIGS = get_gcp_secrets("150030916493", "bot-api-secrets")
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

        bot_configs = BotConfig(**APP_CONFIGS["BOT"])
        bot_specialist = OpenAIBotSpecialist(bot_configs, logger, APP_CONFIGS)
        documents = await bot_specialist.get_context(request)
        chunks = [doc.model_dump() for doc in documents]
        answer = bot_specialist.answer_question(request.query, chunks)
        bot_specialist.record_dialogue(answer, request)

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
        bot_configs = BotConfig(**APP_CONFIGS["BOT"])
        bot_specialist = OpenAIBotSpecialist(bot_configs, logger, APP_CONFIGS)
        bot_specialist.record_feedback(request)

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
        logging.error(
            f"Answer question has failed due to: \n\n{err}\n\n", stack_info=True
        )

    return response
