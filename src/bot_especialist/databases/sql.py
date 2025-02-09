import logging
from contextlib import contextmanager
from typing import List, Tuple

import sqlalchemy
from google.cloud.sql.connector import Connector, IPTypes
from pg8000.dbapi import Connection
from sqlalchemy import text
from sqlalchemy.engine import Engine

from bot_especialist.models.connections import CloudSQLConnection
from bot_especialist.utils.tools import read_yaml


class CloudSQL:
    def __init__(self, connection: CloudSQLConnection):
        self.connection_name = connection.connection_name
        self.engine = connection.engine
        self.ip_address = connection.ip_address
        self.db_user = connection.db_user
        self.db_password = connection.db_password
        self.db_name = connection.db_name
        self.use_private_ip = connection.use_private_ip
        self.plugin = connection.plugin
        self.connector = Connector()

    def __get_connection(self) -> Engine:
        def getconn() -> Connection:
            conn = self.connector.connect(
                self.connection_name,
                self.plugin,
                user=self.db_user,
                password=self.db_password,
                db=self.db_name,
                ip_type=IPTypes.PRIVATE if self.use_private_ip else IPTypes.PUBLIC,
            )
            return conn

        engine = sqlalchemy.create_engine(
            f"{self.engine}+{self.plugin}://{self.ip_address}",
            creator=getconn,
        )
        return engine

    @contextmanager
    def __session_scope(self) -> Connection:
        """Provide a transactional scope around a series of operations."""
        engine = self.__get_connection()
        connection = engine.connect()
        transaction = connection.begin()
        logging.info("Initialized SQL connection.")
        try:
            yield connection
            transaction.commit()
        except Exception as err:
            transaction.rollback()
            logging.warning(
                f"Rolled back the transaction on SQL due to the error: {err}."
            )
            raise err
        finally:
            connection.close()
            self.connector.close()
            logging.info("Closed connection from SQL.")

    def run_query(self, query: str) -> List[Tuple]:
        try:
            with self.__session_scope() as session:
                # Convert the string query to a SQLAlchemy text object
                sql = text(query)
                result = session.execute(sql)  # Execute the query
                logging.info("Executed query successfully on SQL.")
                rows = result.fetchall()  # Fetch the rows
                return rows
        except Exception as err:
            logging.error(f"Failed to run query on SQL: \n\n{err}\n\n")
            raise err


# Usage example:
if __name__ == "__main__":
    configs = read_yaml("app-configs.yml")
    info_conn = configs["CONNECTIONS"]["TEST"]
    conn = CloudSQLConnection(**info_conn)

    cloud_sql = CloudSQL(connection=conn)
    query = "SELECT * FROM climate_data;"
    rows = cloud_sql.run_query(query)
    if rows:
        for row in rows:
            print(row)  # Print each row
    else:
        print("No data retrieved.")
