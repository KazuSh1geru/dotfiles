# DDD パターン集

## Value Object (値オブジェクト)

**いつ使う:** 値そのものに意味があり、バリデーションや変換ロジックを持つとき。

### Python 実装

```python
from dataclasses import dataclass
import re

@dataclass(frozen=True)
class EmailAddress:
    value: str

    def __post_init__(self) -> None:
        if not re.match(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$", self.value):
            raise ValueError(f"Invalid email: {self.value}")

    def domain(self) -> str:
        return self.value.split("@")[1]


@dataclass(frozen=True)
class Money:
    amount: int  # 最小単位（円、セント）で保持
    currency: str

    def __post_init__(self) -> None:
        if self.amount < 0:
            raise ValueError(f"Amount must be non-negative: {self.amount}")
        if self.currency not in ("JPY", "USD", "EUR"):
            raise ValueError(f"Unsupported currency: {self.currency}")

    def add(self, other: "Money") -> "Money":
        if self.currency != other.currency:
            raise ValueError(f"Cannot add {self.currency} and {other.currency}")
        return Money(amount=self.amount + other.amount, currency=self.currency)


@dataclass(frozen=True)
class UserId:
    value: str

    def __post_init__(self) -> None:
        if not self.value:
            raise ValueError("UserId cannot be empty")

    @classmethod
    def generate(cls) -> "UserId":
        import uuid
        return cls(value=str(uuid.uuid4()))
```

### TypeScript 実装

```typescript
class EmailAddress {
  private constructor(readonly value: string) {}

  static create(value: string): EmailAddress {
    if (!/^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$/.test(value)) {
      throw new Error(`Invalid email: ${value}`);
    }
    return new EmailAddress(value);
  }

  equals(other: EmailAddress): boolean {
    return this.value === other.value;
  }

  get domain(): string {
    return this.value.split("@")[1];
  }
}

class Money {
  private constructor(
    readonly amount: number,
    readonly currency: "JPY" | "USD" | "EUR",
  ) {}

  static create(amount: number, currency: "JPY" | "USD" | "EUR"): Money {
    if (amount < 0) throw new Error(`Amount must be non-negative: ${amount}`);
    return new Money(amount, currency);
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new Error(`Cannot add ${this.currency} and ${other.currency}`);
    }
    return Money.create(this.amount + other.amount, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}
```

### VO 設計ルール

- **frozen / immutable**: 作成後に変更しない。変更は新しいインスタンスを返す
- **等価性は値で判定**: `@dataclass(frozen=True)` なら自動。TypeScript は `equals()` を実装
- **バリデーションはコンストラクタで**: 不正な状態のインスタンスを作らせない
- **ドメインロジックを持てる**: `Money.add()`, `EmailAddress.domain()` のように

## Entity (エンティティ)

**いつ使う:** ライフサイクルがあり、IDで識別される概念。

### Python 実装

```python
@dataclass
class User:
    id: UserId
    name: str
    email: EmailAddress
    created_at: datetime

    def change_email(self, new_email: EmailAddress) -> None:
        self.email = new_email

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, User):
            return NotImplemented
        return self.id == other.id

    def __hash__(self) -> int:
        return hash(self.id)
```

### Entity 設計ルール

- **ID で等価性を判定**: 同じ ID なら同じエンティティ
- **状態変更メソッドを持つ**: `change_email()`, `activate()` 等
- **不変条件をメソッド内で守る**: 状態遷移のルールをエンティティ自身が強制する

## Repository (リポジトリ)

**いつ使う:** 永続化の詳細をドメイン層から隠し、テストで差し替え可能にしたいとき。

### Python 実装 (Protocol ベース)

```python
from typing import Protocol

class UserRepository(Protocol):
    def find_by_id(self, user_id: UserId) -> User | None: ...
    def find_by_email(self, email: EmailAddress) -> User | None: ...
    def save(self, user: User) -> None: ...
    def delete(self, user_id: UserId) -> None: ...


# infrastructure/repositories/sqlalchemy_user_repository.py
class SqlAlchemyUserRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def find_by_id(self, user_id: UserId) -> User | None:
        row = self._session.query(UserRow).filter_by(id=user_id.value).first()
        if row is None:
            return None
        return self._to_domain(row)

    def save(self, user: User) -> None:
        row = self._to_row(user)
        self._session.merge(row)

    def _to_domain(self, row: UserRow) -> User:
        return User(
            id=UserId(row.id),
            name=row.name,
            email=EmailAddress(row.email),
            created_at=row.created_at,
        )

    def _to_row(self, user: User) -> UserRow:
        return UserRow(
            id=user.id.value,
            name=user.name,
            email=user.email.value,
            created_at=user.created_at,
        )
```

### TypeScript 実装

```typescript
interface UserRepository {
  findById(userId: UserId): Promise<User | null>;
  findByEmail(email: EmailAddress): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(userId: UserId): Promise<void>;
}

// infrastructure/repositories/prismaUserRepository.ts
class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(userId: UserId): Promise<User | null> {
    const row = await this.prisma.user.findUnique({
      where: { id: userId.value },
    });
    if (!row) return null;
    return this.toDomain(row);
  }

  async save(user: User): Promise<void> {
    await this.prisma.user.upsert({
      where: { id: user.id.value },
      create: this.toRow(user),
      update: this.toRow(user),
    });
  }

  private toDomain(row: PrismaUser): User {
    return new User(
      UserId.create(row.id),
      row.name,
      EmailAddress.create(row.email),
      row.createdAt,
    );
  }
}
```

### Repository 設計ルール

- **インターフェースは domain 層に置く**: `domain/repositories/`
- **実装は infrastructure 層に置く**: `infrastructure/repositories/`
- **ドメインオブジェクトを返す**: Row/DTO ではなく Entity を返す
- **変換ロジックは Repository 内に閉じる**: `_to_domain()` / `_to_row()`
- **Protocol (Python) / interface (TypeScript)** で定義し、実装との結合を切る

## Application Service (ユースケース)

**いつ使う:** ドメインオブジェクトを組み合わせてユースケースを実現する薄い層。

```python
class RegisterUser:
    def __init__(self, user_repository: UserRepository) -> None:
        self._user_repository = user_repository

    def execute(self, name: str, email: str) -> User:
        email_vo = EmailAddress(email)

        existing = self._user_repository.find_by_email(email_vo)
        if existing is not None:
            raise DuplicateEmailError(f"Email already registered: {email}")

        user = User(
            id=UserId.generate(),
            name=name,
            email=email_vo,
            created_at=datetime.now(UTC),
        )
        self._user_repository.save(user)
        return user
```

### Application Service 設計ルール

- **薄く保つ**: ビジネスロジックは Entity / VO / Domain Service に書く
- **依存は Protocol 経由で注入**: コンストラクタインジェクション
- **トランザクション境界はここで管理**: 必要なら
- **ドメイン例外はここでは捕まえない**: presentation 層に任せる

## パターン適用の判断フロー

```
タスクの複雑度を見る
├── 単純な CRUD → パターン不要。関数 + ORM 直接呼び出し
├── バリデーションルールがある → Value Object を導入
├── 状態遷移がある → Entity を導入
├── テストで外部依存を切りたい → Repository を導入
└── 複数のドメインオブジェクトを協調させる → Application Service を導入
```

**原則: 必要になるまで導入しない。先に導入して「いつか使うだろう」は禁止。**
