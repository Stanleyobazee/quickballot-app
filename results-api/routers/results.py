import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from models import Poll, PollOption, Vote
from database import get_db

router = APIRouter(prefix="/api/results", tags=["results"])


@router.get("/{poll_id}")
async def get_results(poll_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    # Load poll with options
    poll = await db.get(Poll, poll_id)
    if poll is None:
        raise HTTPException(status_code=404, detail="Poll not found")

    # Count votes per option in one query
    vote_counts_q = (
        select(Vote.option_id, func.count(Vote.id).label("count"))
        .where(Vote.poll_id == poll_id)
        .group_by(Vote.option_id)
    )
    rows = (await db.execute(vote_counts_q)).all()
    counts: dict[uuid.UUID, int] = {row.option_id: row.count for row in rows}

    total = sum(counts.values())

    options_result = []
    for opt in sorted(poll.options, key=lambda o: o.display_order):
        vote_count = counts.get(opt.id, 0)
        percentage = round((vote_count / total * 100), 1) if total > 0 else 0.0
        options_result.append({
            "id": str(opt.id),
            "label": opt.label,
            "display_order": opt.display_order,
            "vote_count": vote_count,
            "percentage": percentage,
        })

    return {
        "poll_id": str(poll.id),
        "question": poll.question,
        "status": poll.status,
        "total_votes": total,
        "options": options_result,
    }


@router.get("")
async def list_results(db: AsyncSession = Depends(get_db)):
    """Return lightweight results summary for all polls (newest first)."""
    polls_q = select(Poll).order_by(Poll.created_at.desc())
    polls = (await db.execute(polls_q)).scalars().all()

    # Single query: total votes per poll
    totals_q = (
        select(Vote.poll_id, func.count(Vote.id).label("total"))
        .group_by(Vote.poll_id)
    )
    totals = {row.poll_id: row.total for row in (await db.execute(totals_q)).all()}

    return [
        {
            "poll_id": str(p.id),
            "question": p.question,
            "status": p.status,
            "total_votes": totals.get(p.id, 0),
            "created_at": p.created_at.isoformat(),
        }
        for p in polls
    ]