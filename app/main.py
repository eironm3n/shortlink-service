from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import engine, get_db
from app.models import Base, Link
from app.schemas import LinkCreate, LinkOut
from app.shortcode import generate_code

settings = get_settings()
Base.metadata.create_all(bind=engine)

app = FastAPI(title="shortlink-service", version=settings.version)

_MAX_CODE_ATTEMPTS = 5


def _to_out(link: Link) -> LinkOut:
    return LinkOut(
        code=link.code,
        target_url=link.target_url,
        short_url=f"{settings.base_url.rstrip('/')}/{link.code}",
        visits=link.visits,
    )


@app.get("/healthz", tags=["ops"])
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/version", tags=["ops"])
def version() -> dict[str, str]:
    return {"version": settings.version}


@app.post("/api/links", response_model=LinkOut, status_code=201, tags=["links"])
def create_link(payload: LinkCreate, db: Session = Depends(get_db)) -> LinkOut:
    code = ""
    for _ in range(_MAX_CODE_ATTEMPTS):
        candidate = generate_code(settings.code_length)
        if db.scalar(select(Link).where(Link.code == candidate)) is None:
            code = candidate
            break
    if not code:
        raise HTTPException(status_code=503, detail="could not allocate a unique code")

    link = Link(code=code, target_url=str(payload.target_url))
    db.add(link)
    db.commit()
    db.refresh(link)
    return _to_out(link)


@app.get("/api/links/{code}", response_model=LinkOut, tags=["links"])
def get_link(code: str, db: Session = Depends(get_db)) -> LinkOut:
    link = db.scalar(select(Link).where(Link.code == code))
    if link is None:
        raise HTTPException(status_code=404, detail="unknown code")
    return _to_out(link)


@app.get("/{code}", tags=["links"])
def follow(code: str, db: Session = Depends(get_db)) -> RedirectResponse:
    link = db.scalar(select(Link).where(Link.code == code))
    if link is None:
        raise HTTPException(status_code=404, detail="unknown code")
    link.visits += 1
    db.commit()
    return RedirectResponse(url=link.target_url, status_code=307)
