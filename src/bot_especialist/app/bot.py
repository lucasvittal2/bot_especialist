from datetime import datetime
from logging import Logger
from typing import List, Tuple, Union

import pytz  # type: ignore
from langchain.prompts import ChatPromptTemplate
from langchain_community.chat_models import ChatOpenAI
from langchain_core.documents import Document
from langchain_google_vertexai import VertexAIEmbeddings

from bot_especialist.databases.sql import CloudSQL
from bot_especialist.databases.vector_store import AlloyDB
from bot_especialist.models.configs import AlloyTableConfig, BotConfig
from bot_especialist.models.connections import AlloyDBConnection, CloudSQLConnection
from bot_especialist.models.data import FeedbackRequest, QueryRequest
from bot_especialist.utils.tools import generate_hash


class OpenAIBotSpecialist:
    def __init__(self, bot_config: BotConfig, logger: Logger, app_configs):
        self.LLM_MODEL = bot_config.llm_model
        self.PROMPT = bot_config.prompt
        self.SYS_INSTRUCTIONS = bot_config.sys_instructions
        self.logger = logger

        cloud_sql_connection = CloudSQLConnection(**app_configs["CONNECTIONS"]["TRACK"])
        self.cloud_sql = CloudSQL(cloud_sql_connection, logger)
        self.VECTOR_STORE_CONFIGS = app_configs["VECTOR_STORE"]
        self.TZ_REGION = app_configs["TIME_ZONE"]
        embedding_model = VertexAIEmbeddings(
            model_name=app_configs["GCP_EMBEDDING_MODEL"],
            project=app_configs["GCP_PROJECT"],
        )
        alloydb_connection = AlloyDBConnection(**app_configs["CONNECTIONS"]["ALLOYDB"])
        self.vector_store = AlloyDB(
            connection=alloydb_connection,
            embedding_model=embedding_model,
            openai_key=app_configs["OPENAI_API_KEY"],
            logger=logger,
        )

    def __format_context_prompt_entries(self, chunks: List[dict]) -> Tuple[str, str]:
        contents = []
        metadata_records = []
        self.logger.info("Formatting prompt entries... ")
        for chunk in chunks:
            content = chunk["page_content"]
            metadata = chunk["metadata"]
            pagen_number = metadata["page_number"]
            source_doc = metadata["page_number"]
            contents.append(content)
            metadata_records.append(
                f"at document '{source_doc}' in page {pagen_number}"
            )

        context = "\n".join(contents)
        metadata = "\n".join(metadata_records)
        self.logger.info("Entries were formatted !")
        return context, metadata

    def answer_question(self, query: str, chunks: List[dict]) -> Union[str, None]:
        try:
            self.logger.info("Processing user's query...")
            messages = [
                ("system", self.SYS_INSTRUCTIONS),
                ("human", self.PROMPT),
            ]
            prompt = ChatPromptTemplate.from_messages(messages)
            llm = ChatOpenAI(temperature=0.0, model=self.LLM_MODEL)
            chain = prompt | llm
            context, metadata = self.__format_context_prompt_entries(chunks)
            answer = chain.invoke(
                {"question": query, "context": context, "metadata": metadata}
            )
            self.logger.info(f"Got answer for question {query} successfully !")

            return answer.content
        except Exception as err:
            self.logger.error(
                f"Failed to Answer user's question due to following error: \n\n{err}\n\n"
            )
            raise err

    def record_dialogue(self, answer: str, request: QueryRequest) -> None:
        dialogue_id = generate_hash(answer)
        try:
            created_at = datetime.now(tz=pytz.timezone(self.TZ_REGION)).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            self.cloud_sql.run_query(
                """
                INSERT INTO track.dialogues
                (id, user_id, created_at, question, answer)
                VALUES ('%s','%s', '%s', '%s', '%s')
                """
                % (dialogue_id, request.user_id, created_at, request.query, answer)
            )
            self.logger.info(f"Dialogue '{dialogue_id}' recorded sucessfully")

        except Exception as err:
            self.logger.error(
                f"Error when recording dialogue '{dialogue_id}': \n\n{err}\n\n"
            )
            raise err

    def record_feedback(self, request: FeedbackRequest) -> None:
        dialogue_id = request.dialogue_id
        try:

            self.logger.info(
                f"Recording User's feedback for dialogue '{dialogue_id}'..."
            )
            created_at = datetime.now(tz=pytz.timezone(self.TZ_REGION)).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            user_id = request.user_id
            dialogue_id = dialogue_id
            feedback = request.feedback
            self.cloud_sql.run_query(
                """
                INSERT INTO track.feedbacks
                (user_id, dialogue_id, created_at, feedback)
                VALUES ('%s','%s' ,'%s', '%s')
                """
                % (user_id, dialogue_id, created_at, feedback)
            )
            self.logger.info(
                f"User's feedback for dialogue '{dialogue_id}' was recorded successfully !"
            )
        except Exception as err:
            self.logger.error(
                f"Got error during recording of user's feedback for {dialogue_id}: \n\n{err}\n\n"
            )
            raise err

    async def get_context(self, request: QueryRequest) -> List[Document]:
        try:
            self.logger.info(
                "Getting context which supports answer for user's question..."
            )
            async with self.vector_store:
                filters = " AND ".join(request.filters)
                table_config = AlloyTableConfig(**self.VECTOR_STORE_CONFIGS)
                await self.vector_store.init_vector_storage_table(
                    table="bot-brain", table_config=table_config
                )
                documents = await self.vector_store.search_documents(
                    request.query, filters
                )
            self.logger.info("Got the necessary context to answer user's question.")
            return documents
        except Exception as err:
            self.logger.error(
                f"Got Error when getting context to answer question: \n\n{err}\n\n"
            )
            raise err
