from typing import List, Tuple

from langchain.prompts import ChatPromptTemplate
from langchain_community.chat_models import ChatOpenAI

from bot_especialist.models.configs import BotConfig


class OpenAIBotSpecialist:
    def __init__(self, bot_config: BotConfig):
        self.LLM_MODEL = bot_config.llm_model
        self.PROMPT = bot_config.prompt
        self.SYS_INSTRUCTIONS = bot_config.sys_instructions

    @staticmethod
    def __format_context_prompt_entries(chunks: List[dict]) -> Tuple[str, str]:
        contents = []
        metadata_records = []
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
        return context, metadata

    def answer_question(self, query: str, chunks: List[dict]) -> str:
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
        return answer.content
