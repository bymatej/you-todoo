from application.model import YouTodooTask, db


def find_all_tasks() -> list:
    return YouTodooTask.query.order_by(YouTodooTask.date_created).all()


def find_task_by_id(ytdtask_id: int) -> YouTodooTask:
    return YouTodooTask.query.get_or_404(ytdtask_id)


def create_task(ytdtask_content: str):
    ytdtask = YouTodooTask(content=ytdtask_content)
    db.session.add(ytdtask)
    db.session.commit()


def delete_task(ytdtask_id: int):
    ytdtask = find_task_by_id(ytdtask_id)
    db.session.delete(ytdtask)
    db.session.commit()


def update_task(ytdtask_id: int, ytdtask_content: str):
    ytdtask = find_task_by_id(ytdtask_id)
    ytdtask.content = ytdtask_content
    db.session.commit()
