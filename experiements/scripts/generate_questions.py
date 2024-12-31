from typing import List
from langchain_community.document_loaders import PyPDFLoader
from langchain.output_parsers import ResponseSchema
from langchain.output_parsers import StructuredOutputParser
from langchain_community.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
import dotenv
import yaml
import asyncio
import json



def save_list_of_dicts_to_json(data: list, file_path: str):
    """
    Saves a list of dictionaries to a JSON file.
    
    Parameters:
    - data (list): List of dictionaries to save.
    - file_path (str): Path where the JSON file will be saved.
    """
    try:
       
        with open(file_path, 'w') as json_file:
            json.dump(data, json_file, indent=4)
        print(f"Data successfully saved to {file_path}")
    except Exception as e:
        print(f"An error occurred: {e}")

def read_yaml(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)  # Load the YAML data
    return data

async def get_pdf_pages(pdf_path:str)-> List[str]:
    loader = PyPDFLoader(pdf_path)
    pages = []
    async for page in loader.alazy_load():
        pages.append(page.page_content)
    return pages

    

def generate_qa(source_text: str, prompt_template: str, llm_model = "gpt-4o-mini") -> List[dict]:
    question_schema = ResponseSchema(name="question",
                                description="A generic question made by a user about a especific subject.")

    answer_schema = ResponseSchema(name="question",
                                description="An answer provided by a given question")
    
    response_schemas = [question_schema, answer_schema]
    output_parser = StructuredOutputParser.from_response_schemas(response_schemas)
    format_instructions = output_parser.get_format_instructions()

    prompt = ChatPromptTemplate.from_template(template=prompt_template)
    messages = prompt.format_messages(text=source_text, 
                                    format_instructions=format_instructions)
    chat = ChatOpenAI(temperature=0.0, model=llm_model)
    response = chat(messages)
    output_dict = output_parser.parse(response.content)
    return output_dict


if __name__ == "__main__":

    QUESTION_AMOUNT_PER_PAGE = 4
    PDF_PATH="assets/pdf/fundamentals-data-engineering-chap1.pdf"
    PROMPTS_YAML = "assets/yaml/prompts.yaml"
    LLM_MODEL="gpt-4o-mini"

    dotenv.load_dotenv("./.env")
    prompts = read_yaml(PROMPTS_YAML)
    pages =  asyncio.run(get_pdf_pages(PDF_PATH))
    generate_qa_prompt = prompts["GENERATE_QA_PROMPT"]
    records_qa = []
    for page in pages:
        for _ in range(QUESTION_AMOUNT_PER_PAGE):
            groudtruth_qa = generate_qa(page,generate_qa_prompt )
            records_qa.append(groudtruth_qa)
    
    
    save_list_of_dicts_to_json(records_qa, "assets/json/QA_groundTruth.json")
