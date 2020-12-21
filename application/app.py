from application.controller.task_controller import app
from application.model.models import db

# Run point
if __name__ == "__main__":
    with app.app_context():
        db.init_app(app)
        db.create_all()
    app.run(debug=True)
