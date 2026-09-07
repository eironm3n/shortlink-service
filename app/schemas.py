from pydantic import BaseModel, HttpUrl


class LinkCreate(BaseModel):
    target_url: HttpUrl


class LinkOut(BaseModel):
    code: str
    target_url: str
    short_url: str
    visits: int
