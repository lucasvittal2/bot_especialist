import asyncio
import gc
import os
from logging import Logger
from typing import Any, List, Union

import aiohttp
from langchain_core.documents import Document
from langchain_core.embeddings.embeddings import Embeddings
from langchain_google_alloydb_pg import AlloyDBEngine, AlloyDBVectorStore
from langchain_google_vertexai import VertexAIEmbeddings

from bot_especialist.models.configs import AlloyTableConfig
from bot_especialist.models.connections import AlloyDBConnection


class AlloyDB:
    def __init__(
        self,
        connection: AlloyDBConnection,
        embedding_model: Embeddings,
        openai_key: str,
        logger: Logger,
    ):
        self.engine: Union[AlloyDBEngine, None] = None
        self.connection = connection
        self.embedding_model = embedding_model
        self.db_schema = connection.db_schema
        self.vector_store: Union[AlloyDBVectorStore, None] = None
        self.openai_key = openai_key
        self.logger = logger

    async def __aenter__(self):
        """Async context manager for initializing resources."""

        self.engine = await AlloyDBEngine.afrom_instance(
            project_id=self.connection.project_id,
            region=self.connection.region,
            cluster=self.connection.cluster,
            instance=self.connection.instance,
            database=self.connection.database,
            user=self.connection.db_user,
            password=self.connection.db_password,
        )

        return self

    async def __aexit__(self, exc_type, exc_value, traceback):
        """Async context manager for cleaning up resources."""
        await self.__close_all_sessions_and_connections()

        self.logger.info("Closed all connections related with AlloyDB.")

    async def __close_all_sessions_and_connections(self):
        """Close all open aiohttp sessions and their connections."""
        os.environ["OPENAI_API_KEY"] = self.openai_key
        sessions = [
            obj for obj in gc.get_objects() if isinstance(obj, aiohttp.ClientSession)
        ]

        if not sessions:
            self.logger.info("No open ClientSession objects found.")
            return

        for session in sessions:

            self.logger.info(f"Found ClientSession: {session}")

            if not session.closed:

                # Close the session
                await session.close()
                self.logger.info(f"Closed ClientSession: {session} .")

                # Close its connector explicitly if still open
                connector = session.connector
                if connector and not connector.closed:
                    await connector.close()
                    self.logger.info(f"Closed Connector: {connector} .")
            else:
                self.logger.info(f"ClientSession {session} is already closed.")

    async def init_vector_storage_table(
        self, table: str, table_config: AlloyTableConfig
    ) -> None:
        """Initialize the vector storage table."""
        try:
            self.vector_store = await AlloyDBVectorStore.create(
                engine=self.engine,
                table_name=table,
                schema_name=self.connection.db_schema,
                embedding_service=self.embedding_model,
                id_column=table_config.id_column,
                content_column=table_config.content_column,
                embedding_column=table_config.embedding_column,
                metadata_columns=table_config.metadata_columns,
                metadata_json_column=table_config.metadata_json_column,
            )
            self.logger.info(f"Initialized vector storage table: {table}")
        except Exception as err:
            self.logger.error(f"Failed to initialize vector storage: {err}")
            raise

    async def add_records(
        self, table: str, contents: List[str], metadata: List[dict], ids: List[Any]
    ) -> None:
        """Add documents to the vector store."""
        if self.vector_store is None:
            raise Exception(
                "Initialize the vector storage table before call this function, otherwise you'll not be able to adding records !"
            )
        if len(contents) != len(metadata):
            raise ValueError("Contents and metadata lists should have same lengths")

        try:
            documents = [
                Document(page_content=content, metadata=meta)
                for content, meta in zip(contents, metadata)
            ]

            await self.vector_store.aadd_texts(contents, metadatas=metadata, ids=ids)
            self.logger.info(f"Added {len(documents)} documents successfully.")
        except Exception as err:
            self.logger.error(f"Failed to add documents: {err}")
            raise err

    async def search_documents(self, query: str, filter: str = "") -> List[Document]:
        """Search documents in the vector store."""
        if self.vector_store is None:
            raise Exception(
                "Initialize the vector storage table before call this function, otherwise you'll not be able to search documents !"
            )
        try:
            docs = await self.vector_store.asimilarity_search(query, filter=filter)
            self.logger.info(f"Found {len(docs)} documents for query: {query}")
            return docs
        except Exception as err:
            self.logger.error(f"Failed to search documents: {err}")
            raise err


if __name__ == "__main__":
    import warnings

    from bot_especialist.utils.app_logging import LoggerHandler
    from bot_especialist.utils.tools import read_yaml

    warnings.filterwarnings("ignore")

    async def main():

        # Load configurations
        app_config = read_yaml("configs/app-configs.yml")
        connection_config = app_config["CONNECTIONS"]["ALLOYDB"]
        connection = AlloyDBConnection(**connection_config)
        logger = LoggerHandler(
            logger_name="TESTING-VECTOR-STORE", logging_type="console"
        ).get_logger()
        # Create embedding model
        embedding_model = VertexAIEmbeddings(
            model_name="textembedding-gecko@latest", project=app_config["GCP_PROJECT"]
        )

        # Initialize vector store
        db = AlloyDB(connection, embedding_model, app_config["OPENAI_API_KEY"], logger)
        async with db:
            table_config = AlloyTableConfig(**app_config["VECTOR_STORE"])
            await db.init_vector_storage_table(
                table="bot-brain", table_config=table_config
            )

            # Query vector store
            query = "What is Data engineering"
            docs = await db.search_documents(query)
            print(docs)

    asyncio.run(main())
