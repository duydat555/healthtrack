from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.user import User


class CRUDUser(CRUDBase[User]):
    async def get_by_email(self, db: AsyncSession, email: str) -> User | None:
        stmt = select(User).where(User.email == email.lower())
        return (await db.execute(stmt)).scalar_one_or_none()


# User không thuộc về user khác nên không lọc theo user_id
user_crud = CRUDUser(User, owner_field=None)
