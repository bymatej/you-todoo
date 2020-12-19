from datetime import datetime

from __main__ import app
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy(app)


# with app.test_request_context():
#     db.init_app(app)
#     db.create_all()


class YouTodooTask(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.String(200), nullable=False)
    completed = db.Column(db.Integer, default=0)
    date_created = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return '<Task %r>' % self.id
