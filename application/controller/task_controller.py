from flask import Flask
from flask import render_template, request, redirect

from application.config import TestingConfig
from application.service.task_service import find_all_tasks, create_task, delete_task, update_task, find_task_by_id

app = Flask(__name__, template_folder='../templates', static_folder='../static')
app.config.from_object(TestingConfig())


@app.route('/', methods=['POST', 'GET'])
def index():
    if request.method == 'POST':
        task_content = request.form['content']
        try:
            create_task(task_content)
            return redirect('/')
        except:
            return "There was an issue adding your task"
    else:
        tasks = find_all_tasks()
        return render_template('index.html', tasks=tasks)


@app.route('/delete/<int:id>')
def delete(id):
    try:
        delete_task(id)
        return redirect('/')
    except:
        return "There was a problem deleting that task"


@app.route('/update/<int:id>', methods=['GET', 'POST'])
def update(id):
    if request.method == 'POST':
        content = request.form['content']
        try:
            update_task(id, content)
            return redirect('/')
        except:
            return "There was an error updating your task"
    else:
        return render_template('update.html', task=find_task_by_id(id))
