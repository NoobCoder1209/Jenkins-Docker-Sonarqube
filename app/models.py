from pydantic import BaseModel, Field


class EchoRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=500)
