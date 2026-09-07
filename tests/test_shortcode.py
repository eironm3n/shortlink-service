from app.shortcode import generate_code


def test_length() -> None:
    assert len(generate_code(7)) == 7
    assert len(generate_code(12)) == 12


def test_alphanumeric() -> None:
    assert generate_code(64).isalnum()


def test_codes_are_practically_unique() -> None:
    codes = {generate_code(7) for _ in range(2000)}
    assert len(codes) == 2000
