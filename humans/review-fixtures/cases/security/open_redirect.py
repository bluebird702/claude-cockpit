"""로그인 후 리다이렉트 처리."""

from flask import redirect, request

from app.auth import authenticate


def login_handler():
    account = authenticate(
        email=request.form["email"],
        password=request.form["password"],
    )
    if account is None:
        return redirect("/login?error=1")
    next_url = request.args.get("next", "/dashboard")
    return redirect(next_url)
