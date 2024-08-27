from __future__ import annotations

from enum import Enum
from typing import List, Optional, Union

from pydantic import BaseModel


class QuestionSchema(BaseModel):
    entrypoint: str
    questions: List[Question]
    envs_configuration: List[EnvConfiguration]

    class Config:
        title = "QuestionSchema"


class Question(BaseModel):
    id: str
    question: str
    var: str
    default: Union[str, int]
    validation: List[ValidationObject]
    post_processing: List[PostProcessingStep]
    next: NextStep

    class Config:
        title = "Question"


class ValidationObject(BaseModel):
    func: ValidationFuncEnum
    args: List[str]
    success: ValidationSuccessEnum
    err_msg: str

    class Config:
        title = "ValidationObject"


class ValidationFuncEnum(str, Enum):
    regex = "regex"
    lowercase = "lowercase"
    kubectlget = "kubectlget"
    onlythesevalues = "onlythesevalues"


class ValidationSuccessEnum(str, Enum):
    noerror = "noerror"
    notempty = "notempty"


class PostProcessingStep(BaseModel):
    func: PostProcessingStepFuncEnum

    class Config:
        title = "PostProcessingStep"


class PostProcessingStepFuncEnum(str, Enum):
    lowercase = "lowercase"


class NextStep(BaseModel):
    value: str
    conditions: List[Condition]

    class Config:
        title = "NextStep"


class Condition(BaseModel):
    when: str
    question_id: Optional[str]
    action: ActionEnum
    expose: List[ExposeAction]

    class Config:
        title = "Condition"


class ExposeAction(BaseModel):
    name: str
    func: ExposeActionFuncEnum
    args: List[str]

    class Config:
        title = "ExposeAction"


class ExposeActionFuncEnum(str, Enum):
    kubectlget = "kubectlget"
    returnasis = "returnasis"
    concatenate = "concatenate"
    divide = "divide"


class ActionEnum(str, Enum):
    exit = "exit"
    proceed = "proceed"
    complete = "complete"


class EnvConfiguration(BaseModel):
    scope: EnvConfigurationScopeEnum
    envs: List[Env]

    class Config:
        title = "EnvConfiguration"


class EnvConfigurationScopeEnum(str, Enum):
    configenv = ".config.env"
    resourcesenv = ".resources.env"
    authenv = ".auth.env"
    predeploymentopsenv = ".pre.deployment.ops.env"
    postdeploymentopsenv = ".post.deployment.ops.env"
    runtime = "runtime"


class Env(BaseModel):
    name: str
    default: Union[str, int]

    class Config:
        title = "Env"
