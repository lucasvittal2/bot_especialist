from logging import Logger
from typing import List, Tuple, Union

from langchain.prompts import ChatPromptTemplate
from langchain_community.chat_models import ChatOpenAI

from bot_especialist.models.configs import BotConfig


class OpenAIBotSpecialist:
    def __init__(self, bot_config: BotConfig, logger: Logger):
        self.LLM_MODEL = bot_config.llm_model
        self.PROMPT = bot_config.prompt
        self.SYS_INSTRUCTIONS = bot_config.sys_instructions
        self.logger = logger

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
