from typing import List

from pydantic import BaseModel


class QueryRequest(BaseModel):
    user_id: str
    query: str
    filters: List[str]


class FeedbackRequest(BaseModel):
    user_id: str
    feedback: str
    dialogue_id: str
