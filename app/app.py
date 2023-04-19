import os
from typing import Tuple
from urllib.parse import quote_plus

from flask import Flask, jsonify
from flask_sqlalchemy import SQLAlchemy


def _require_db_env() -> Tuple[str, str, str, str]:
    user = os.environ.get("DB_USER")
    password = os.environ.get("DB_PASS")
    host = os.environ.get("DB_HOST")
    name = os.environ.get("DB_NAME")
    missing = [k for k, v in (("DB_USER", user), ("DB_PASS", password), ("DB_HOST", host), ("DB_NAME", name)) if not v]
    if missing:
        raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")
    return user, password, host, name


def build_sqlalchemy_uri() -> str:
    user, password, host, name = _require_db_env()
    return (
        "mysql+pymysql://"
        f"{quote_plus(user)}:{quote_plus(password)}@{host}/{name}"
    )


app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = build_sqlalchemy_uri()
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


class Visit(db.Model):
    id = db.Column(db.Integer, primary_key=True)


with app.app_context():
    db.create_all()


@app.route("/health")
def health():
    """
    Liveness for the load balancer: no database access.

    Learning goal: ALB target health can stay green even when MySQL is down or slow,
    while / still exercises the full app + DB path.
    """
    return jsonify({"status": "ok"}), 200


@app.route("/")
def index():
    new_visit = Visit()
    db.session.add(new_visit)
    db.session.commit()
    count = Visit.query.count()
    return f"<h1>Production App</h1><p>Database hits: {count}</p>"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
