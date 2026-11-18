require "rails_helper"

RSpec.describe PostPolicy do
  let(:admin) { build(:user, :admin) }
  let(:reader) { build(:user) }
  let(:published) { build(:post, :published) }
  let(:draft) { build(:post) }

  it "lets everyone see visible posts but only admins see drafts" do
    expect(described_class.new(nil, published).show?).to be(true)
    expect(described_class.new(reader, draft).show?).to be(false)
    expect(described_class.new(admin, draft).show?).to be(true)
  end

  it "restricts management to admins" do
    %i[index? create? update? destroy? publish? unpublish?].each do |action|
      expect(described_class.new(admin, draft).public_send(action)).to be(true), action.to_s
      expect(described_class.new(reader, draft).public_send(action)).to be(false), action.to_s
      expect(described_class.new(nil, draft).public_send(action)).to be(false), action.to_s
    end
  end

  it "scopes drafts out for non-admins" do
    visible = create(:post, :published)
    hidden = create(:post)
    expect(PostPolicy::Scope.new(nil, Post).resolve).to contain_exactly(visible)
    expect(PostPolicy::Scope.new(create(:user, :admin), Post).resolve).to contain_exactly(visible, hidden)
  end
end

RSpec.describe CommentPolicy do
  let(:author) { create(:user) }
  let(:comment) { create(:comment, user: author) }

  it "requires a logged user to comment" do
    expect(described_class.new(nil, comment).create?).to be(false)
    expect(described_class.new(author, comment).create?).to be(true)
  end

  it "does not allow comments on unpublished posts" do
    expect(described_class.new(author, build(:comment, post: build(:post))).create?).to be(false)
  end

  it "lets the author and admins delete, but only admins moderate" do
    admin = create(:user, :admin)
    stranger = create(:user)

    expect(described_class.new(author, comment).destroy?).to be(true)
    expect(described_class.new(admin, comment).destroy?).to be(true)
    expect(described_class.new(stranger, comment).destroy?).to be(false)
    expect(described_class.new(nil, comment).destroy?).to be(false)
    expect(described_class.new(author, comment).moderate?).to be(false)
    expect(described_class.new(admin, comment).moderate?).to be(true)
  end
end

RSpec.describe AdminPolicy do
  it "only allows admins into the admin area" do
    expect(described_class.new(build(:user, :admin), :admin).access?).to be(true)
    expect(described_class.new(build(:user), :admin).access?).to be(false)
    expect(described_class.new(nil, :admin).access?).to be(false)
  end
end

RSpec.describe UserPolicy do
  it "prevents admins from changing their own role" do
    admin = create(:user, :admin)
    expect(described_class.new(admin, admin).update_role?).to be(false)
    expect(described_class.new(admin, create(:user)).update_role?).to be(true)
  end
end
