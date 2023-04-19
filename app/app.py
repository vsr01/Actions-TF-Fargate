import os
from datetime import datetime, timezone
from typing import Tuple
from urllib.parse import quote_plus

from flask import Flask, jsonify, redirect, render_template, request, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


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


class Task(db.Model):
    __tablename__ = "task"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    details = db.Column(db.String(2000), nullable=False, default="")
    done = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)


# Old demo tables from earlier versions of this repo; dropped so only `task` remains.
_LEGACY_TABLES = ("visit", "guestbook_entry")


def _drop_legacy_tables() -> None:
    with db.engine.begin() as conn:
        for name in _LEGACY_TABLES:
            conn.execute(text(f"DROP TABLE IF EXISTS `{name}`"))


with app.app_context():
    db.create_all()
    _drop_legacy_tables()


@app.route("/health")
def health():
    """
    Liveness for the load balancer: no database access.

    Learning goal: ALB target health can stay green even when MySQL is down or slow,
    while / still exercises the full app + DB path.
    """
    return jsonify({"status": "ok"}), 200


def _task_title_errors(title: str) -> list[str]:
    errors: list[str] = []
    if not title:
        errors.append("Title is required.")
    elif len(title) > 200:
        errors.append("Title is too long (200 characters max).")
    return errors


def _parse_task_id(raw: str | None) -> int | None:
    if raw is None or raw == "":
        return None
    try:
        i = int(raw)
    except ValueError:
        return None
    return i if i > 0 else None


def _ordered_tasks():
    return (
        Task.query.order_by(Task.done.asc(), Task.created_at.desc())
        .limit(200)
        .all()
    )


@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        action = (request.form.get("action") or "").strip()

        if action == "toggle":
            tid = _parse_task_id(request.form.get("task_id"))
            if tid is not None:
                task = db.session.get(Task, tid)
                if task is not None:
                    task.done = not task.done
                    db.session.commit()
            return redirect(url_for("index"))

        if action == "delete":
            tid = _parse_task_id(request.form.get("task_id"))
            if tid is not None:
                task = db.session.get(Task, tid)
                if task is not None:
                    db.session.delete(task)
                    db.session.commit()
            return redirect(url_for("index"))

        if action == "create":
            title = (request.form.get("title") or "").strip()
            details = (request.form.get("details") or "").strip()
            errors = _task_title_errors(title)
            if len(details) > 2000:
                errors.append("Details are too long (2000 characters max).")
            if errors:
                return render_template(
                    "index.html",
                    tasks=_ordered_tasks(),
                    errors=errors,
                    form_title=title,
                    form_details=details,
                )
            db.session.add(Task(title=title, details=details))
            db.session.commit()
            return redirect(url_for("index"))

        return redirect(url_for("index"))

    return render_template(
        "index.html",
        tasks=_ordered_tasks(),
        errors=None,
        form_title="",
        form_details="",
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
