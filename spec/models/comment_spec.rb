require "rails_helper"

RSpec.describe Comment do
  subject { build(:comment) }

  it { is_expected.to validate_presence_of(:body) }
  it { is_expected.to validate_length_of(:body).is_at_most(2_000) }
  it { is_expected.to belong_to(:post) }
  it { is_expected.to belong_to(:user) }

  it "is visible by default and updates the post counter cache" do
    comment = create(:comment)
    expect(comment).to be_visible
    expect(comment.post.reload.comments_count).to eq(1)
  end

  it "records who moderated it" do
    admin = create(:user, :admin)
    comment = create(:comment)

    comment.hide!(by: admin)
    expect(comment).to be_hidden
    expect(comment.moderated_by).to eq(admin)
    expect(comment.moderated_at).to be_present

    comment.restore!(by: admin)
    expect(comment).to be_visible
  end
end
