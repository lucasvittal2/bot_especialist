import logging
import os

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

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
    feedback: str


# Define API Endpoints


@bot_api.post("/bot-especialist/answer_query")
def answer_query(request: QueryRequest):
    try:
        response = JSONResponse(
            content={
                "response": f"the query was {request.query}, answering question will be implemented soon."
            },
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
        response = JSONResponse(
            content={"message": f"the feedback was: {request.feedback}"},
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
