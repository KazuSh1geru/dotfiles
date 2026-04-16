# Ruby (RSpec) テストパターン

## Red: テスト例

```ruby
RSpec.describe EmailAddress do
  describe ".new" do
    context "with valid email" do
      it "stores the value" do
        email = EmailAddress.new("user@example.com")
        expect(email.value).to eq("user@example.com")
      end
    end

    context "with invalid email" do
      it "raises ArgumentError" do
        expect { EmailAddress.new("not-an-email") }.to raise_error(ArgumentError, /Invalid email/)
      end
    end
  end

  describe "#==" do
    it "compares by value" do
      expect(EmailAddress.new("a@b.com")).to eq(EmailAddress.new("a@b.com"))
      expect(EmailAddress.new("a@b.com")).not_to eq(EmailAddress.new("x@y.com"))
    end
  end
end
```

## テスト命名規則

`describe/context/it` の入れ子構造で表現する:

```
describe <対象> do
  context <条件> do
    it <期待結果> do
```

例:
- `describe EmailAddress > context "with invalid format" > it "raises ArgumentError"`
- `describe Order > context "with discount" > it "returns discounted price"`

## Green: 最小実装例

テストを通す最短コードを書く。ハードコードでもいい。

```ruby
# まず最初のテストだけ通す
class EmailAddress
  attr_reader :value

  def initialize(value)
    @value = value
  end
end
```

次のテストを足す → 落ちる → バリデーション追加 → 通す → 繰り返し。

## Fake Repository

```ruby
# domain/repositories/user_repository.rb
module Domain
  module Repositories
    class UserRepository
      def find_by_id(user_id) = raise NotImplementedError
      def save(user) = raise NotImplementedError
    end
  end
end

# spec/fakes/fake_user_repository.rb
class FakeUserRepository < Domain::Repositories::UserRepository
  def initialize = @store = {}
  def find_by_id(user_id) = @store[user_id.value]
  def save(user) = @store[user.id.value] = user
end
```

## 統合テストでの使い方

```ruby
RSpec.describe RegisterUser do
  let(:repo) { FakeUserRepository.new }
  let(:use_case) { RegisterUser.new(user_repository: repo) }

  context "when registering a new user" do
    it "saves the user" do
      result = use_case.execute(name: "Alice", email: "alice@example.com")

      expect(result.name).to eq("Alice")
      saved = repo.find_by_id(result.id)
      expect(saved).not_to be_nil
      expect(saved.email).to eq(EmailAddress.new("alice@example.com"))
    end
  end

  context "when email is already taken" do
    before do
      existing = User.new(id: UserId.generate, name: "Existing", email: EmailAddress.new("alice@example.com"))
      repo.save(existing)
    end

    it "raises DuplicateEmailError" do
      expect { use_case.execute(name: "Alice", email: "alice@example.com") }
        .to raise_error(DuplicateEmailError)
    end
  end
end
```

## 実行パターン

```bash
# 全テスト
bundle exec rspec

# 特定ディレクトリ
bundle exec rspec spec/unit/

# 特定ファイル
bundle exec rspec spec/unit/email_address_spec.rb

# 特定テストケース（行番号指定）
bundle exec rspec spec/unit/email_address_spec.rb:5

# フォーマット指定
bundle exec rspec --format documentation
```
