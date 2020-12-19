# Import Flask
from flask import Flask

# Configure project
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///test.db'

# this is not at the top of the file intentionally, as app needs to be created prior to the DB, and DB needs app
import application.controller.task_controller

# Run point
if __name__ == "__main__":
    app.run(debug=True)
