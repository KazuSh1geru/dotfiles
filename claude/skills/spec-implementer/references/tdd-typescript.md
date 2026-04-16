# TypeScript (vitest/jest) テストパターン

## Red: テスト例

```typescript
describe("EmailAddress", () => {
  test("valid email", () => {
    const email = EmailAddress.create("user@example.com");
    expect(email.value).toBe("user@example.com");
  });

  test("invalid email throws", () => {
    expect(() => EmailAddress.create("not-an-email")).toThrow("Invalid email");
  });

  test("equality", () => {
    expect(EmailAddress.create("a@b.com").equals(EmailAddress.create("a@b.com"))).toBe(true);
  });
});
```

## テスト命名規則

`describe/test` 構造:

```
describe(<対象>, () => {
  test(<条件と期待結果>, () => {
```

例:
- `describe("EmailAddress") > test("invalid format throws ValueError")`
- `describe("Order") > test("with discount returns discounted price")`

## Green: 最小実装例

テストを通す最短コードを書く。ハードコードでもいい。

```typescript
// まず最初のテストだけ通す
class EmailAddress {
  readonly value: string;
  private constructor(value: string) {
    this.value = value;
  }
  static create(value: string): EmailAddress {
    return new EmailAddress(value);
  }
}
```

次のテストを足す → 落ちる → バリデーション追加 → 通す → 繰り返し。

## Fake Repository

```typescript
// domain/repositories/userRepository.ts
interface UserRepository {
  findById(userId: UserId): Promise<User | null>;
  save(user: User): Promise<void>;
}

// tests/fakes/fakeUserRepository.ts
class FakeUserRepository implements UserRepository {
  private store = new Map<string, User>();

  async findById(userId: UserId): Promise<User | null> {
    return this.store.get(userId.value) ?? null;
  }

  async save(user: User): Promise<void> {
    this.store.set(user.id.value, user);
  }
}
```

## 統合テストでの使い方

```typescript
describe("RegisterUser", () => {
  test("register new user", async () => {
    const repo = new FakeUserRepository();
    const useCase = new RegisterUser(repo);

    const result = await useCase.execute({ name: "Alice", email: "alice@example.com" });

    expect(result.name).toBe("Alice");
    const saved = await repo.findById(result.id);
    expect(saved).not.toBeNull();
    expect(saved!.email.value).toBe("alice@example.com");
  });

  test("register duplicate email throws", async () => {
    const repo = new FakeUserRepository();
    const existing = new User(UserId.generate(), "Existing", EmailAddress.create("alice@example.com"));
    await repo.save(existing);
    const useCase = new RegisterUser(repo);

    await expect(useCase.execute({ name: "Alice", email: "alice@example.com" }))
      .rejects.toThrow(DuplicateEmailError);
  });
});
```

## 実行パターン

```bash
# 全テスト
npx vitest run

# 特定ファイル
npx vitest run src/domain/__tests__/emailAddress.test.ts

# ウォッチモード
npx vitest --watch
```
