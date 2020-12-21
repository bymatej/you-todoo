from datetime import datetime

from flask_sqlalchemy import SQLAlchemy

from application.app import app

db = SQLAlchemy(app)

with app.app_context():
    db.init_app(app)
    db.create_all()


class YouTodooTask(db.Model):
    # __tablename__ = "you_todoo_tasks"

    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.String(200), nullable=False)
    completed = db.Column(db.Integer, default=0)
    date_created = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return '<Task %r>' % self.id
