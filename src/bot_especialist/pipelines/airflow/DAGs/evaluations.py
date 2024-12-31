from datetime import datetime, time
from typing import List

import pandas as pd
import yaml
from llm_factory import ModelsFactory


def read_yaml(file_path):
    with open(file_path) as file:
        data = yaml.safe_load(file)  # Load the YAML data
    return data


def generate_ai_response(
    prompt_template: str, prompt_params: dict, llm_model: str = "gpt-4"
) -> str:

    api_test_keys = {"openai-east-us-2": "66edbea3f9324a978d62abd051075aa0"}
    model_factory = ModelsFactory(api_test_keys, environment="local")
    sample_prompt = prompt_template.format(**prompt_params)
    response = model_factory.call_model(sample_prompt)[0][0]
    return response


def get_summary_consistency_evaluation(summary: str, original_text: str) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    cosistency_eval_parms = configs["SUMMARY"]["CONSISTENCY_EVALUATION"]
    prompt_template = cosistency_eval_parms["EVALUATION_PROMPT_TEMPLATE"]
    summary_eval_prompt_params = {
        "summary": summary,
        "source_text": original_text,
        "criteria": cosistency_eval_parms["EVALUATION_CRITERIA"],
        "steps": cosistency_eval_parms["EVALUATION_STEPS"],
        "metric_name": cosistency_eval_parms["METRIC_NAME"],
    }
    evaluation = generate_ai_response(prompt_template, summary_eval_prompt_params)
    return evaluation


def get_summary_consistency_reasoning(
    summary: str, original_text: str, metric_value: int
) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    summary_eval_prompt_params = configs["SUMMARY"]["CONSISTENCY_EVALUATION"]
    prompt_template = summary_eval_prompt_params["REASONING_PROMPT_TEMPLATE"]
    summary_eval_prompt_params = {
        "summary": summary,
        "source_text": original_text,
        "criteria": summary_eval_prompt_params["EVALUATION_CRITERIA"],
        "metric_name": "consistency",
        "metric_value": str(metric_value),
    }
    reasoning = generate_ai_response(prompt_template, summary_eval_prompt_params)
    return reasoning


def check_summaries_match(llm_summary: str, expected_summary: str) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    matching_parms = configs["SUMMARY"]["MATCHING_EVALUATION"]
    prompt_template = matching_parms["EVALUATION_PROMPT_TEMPLATE"]
    summary_eval_prompt_params = {
        "llm_summary": llm_summary,
        "expected_summary": expected_summary,
        "criteria": matching_parms["EVALUATION_CRITERIA"],
        "steps": matching_parms["EVALUATION_STEPS"],
        "metric_name": matching_parms["METRIC_NAME"],
    }
    evaluation = generate_ai_response(prompt_template, summary_eval_prompt_params)
    return evaluation


def get_summaries_match_reasoning(
    llm_summary: str, expected_summary: str, evaluation_value: str
) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    matching_parms = configs["SUMMARY"]["MATCHING_EVALUATION"]
    prompt_template = matching_parms["REASONING_PROMPT_TEMPLATE"]
    summary_eval_prompt_params = {
        "llm_summary": llm_summary,
        "expected_summary": expected_summary,
        "criteria": matching_parms["EVALUATION_CRITERIA"],
        "metric_name": matching_parms["METRIC_NAME"],
        "metric_value": evaluation_value,
    }
    evaluation = generate_ai_response(prompt_template, summary_eval_prompt_params)
    return evaluation


def get_aspects_accuracy(
    llm_keywords: List[str], expected_aspects: str, source_text: str
) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    aspects_eval_params = configs["ASPECTS"]["CONSISTENCY_EVALUATION"]
    prompt_template = aspects_eval_params["EVALUATION_PROMPT_TEMPALTE"]
    aspects_eval_prompt_params = {
        "llm_keywords": ",".join(llm_keywords),
        "expected_aspects": ",".join(expected_aspects),
        "source_text": source_text,
        "criteria": aspects_eval_params["EVALUATION_CRITEREA"],
        "steps": aspects_eval_params["EVALUATION_STEPS"],
        "metric_name": aspects_eval_params["METRIC_NAME"],
    }
    evaluation = generate_ai_response(prompt_template, aspects_eval_prompt_params)
    return evaluation


def get_aspects_consistency_reasoning(
    llm_keywords: str, expected_aspects: str, metric_value: int
) -> str:
    configs = read_yaml("../prompts_configs.yaml")
    aspects_reasoning_params = configs["ASPECTS"]["CONSISTENCY_EVALUATION"]
    prompt_template = aspects_reasoning_params["REASONING_PROMPT_TEMPLATE"]
    summary_eval_prompt_params = {
        "llm_keywords": llm_keywords,
        "expected_aspects": expected_aspects,
        "criteria": aspects_reasoning_params["EVALUATION_CRITEREA"],
        "metric_name": aspects_reasoning_params["METRIC_NAME"],
        "metric_value": str(metric_value),
    }
    reasoning = generate_ai_response(prompt_template, summary_eval_prompt_params)
    return reasoning


def get_aspect_matching_reasoning(
    aspects_generated: List[str], expected_aspects: List[str]
):
    configs = read_yaml("../prompts_configs.yaml")
    aspects_matching_params = configs["ASPECTS"]["MATCHING_EVALUATION"]
    prompt_template = aspects_matching_params["REASONING_PROMPT_TEMPLATE"]
    aspects_match_prompt_params = {
        "aspects_generated": ",".join(aspects_generated),
        "aspects_generated": ",".join(expected_aspects),
        "criteria": aspects_matching_params["EVALUATION_CRITERIA"],
        "metric_name": aspects_match_prompt_params["METRIC_NAME"],
    }
    evaluation = generate_ai_response(prompt_template, aspects_match_prompt_params)
    return evaluation


if __name__ == "__main__":

    pass
