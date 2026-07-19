from app.member import Member, Role


def test_member_fields():
    member = Member(member_id="m-1", name="kim", role=Role.OWNER)
    assert member.member_id == "m-1"
    assert member.name == "kim"
    assert member.role == Role.OWNER


def test_role_values():
    assert Role.OWNER.value == "OWNER"
    assert Role.ADMIN.value == "ADMIN"
    assert Role.MEMBER.value == "MEMBER"
