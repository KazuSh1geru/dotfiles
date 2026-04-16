# Python (pytest) テストパターン

## Red: テスト例

```python
class TestEmailAddress:
    def test_valid_email(self):
        email = EmailAddress("user@example.com")
        assert email.value == "user@example.com"

    def test_invalid_email_raises(self):
        with pytest.raises(ValueError, match="Invalid email"):
            EmailAddress("not-an-email")

    def test_equality(self):
        assert EmailAddress("a@b.com") == EmailAddress("a@b.com")
        assert EmailAddress("a@b.com") != EmailAddress("x@y.com")
```

## テスト命名規則

```
test_<対象>_<条件>_<期待結果>
```

例:
- `test_email_address_with_invalid_format_raises_value_error`
- `test_order_total_with_discount_returns_discounted_price`
- `test_user_repository_find_by_id_returns_none_when_not_found`

## Green: 最小実装例

テストを通す最短コードを書く。ハードコードでもいい。

```python
# まず最初のテストだけ通す
class EmailAddress:
    def __init__(self, value: str) -> None:
        self.value = value
```

次のテストを足す → 落ちる → バリデーション追加 → 通す → 繰り返し。

## Fake Repository

```python
# domain/repositories/user_repository.py
from typing import Protocol

class UserRepository(Protocol):
    def find_by_id(self, user_id: UserId) -> User | None: ...
    def save(self, user: User) -> None: ...

# tests/fakes/fake_user_repository.py
class FakeUserRepository:
    def __init__(self) -> None:
        self._store: dict[UserId, User] = {}

    def find_by_id(self, user_id: UserId) -> User | None:
        return self._store.get(user_id)

    def save(self, user: User) -> None:
        self._store[user.id] = user
```

## 統合テストでの使い方

```python
class TestRegisterUser:
    def test_register_new_user(self):
        repo = FakeUserRepository()
        use_case = RegisterUser(user_repository=repo)

        result = use_case.execute(name="Alice", email="alice@example.com")

        assert result.name == "Alice"
        saved = repo.find_by_id(result.id)
        assert saved is not None
        assert saved.email == EmailAddress("alice@example.com")

    def test_register_duplicate_email_raises(self):
        repo = FakeUserRepository()
        existing = User(id=UserId.generate(), name="Existing", email=EmailAddress("alice@example.com"))
        repo.save(existing)
        use_case = RegisterUser(user_repository=repo)

        with pytest.raises(DuplicateEmailError):
            use_case.execute(name="Alice", email="alice@example.com")
```

## 実行パターン

```bash
# 単体テストのみ
pytest tests/unit/ -v

# 統合テストのみ
pytest tests/integration/ -v

# 特定テストクラス
pytest tests/unit/test_email_address.py::TestEmailAddress -v

# 特定テストケース
pytest tests/unit/test_email_address.py::TestEmailAddress::test_valid_email -v

# カバレッジ付き
pytest --cov=src --cov-report=term-missing
```
