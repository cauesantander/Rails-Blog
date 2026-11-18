require "rails_helper"

RSpec.describe Post do
  describe "validations" do
    subject { build(:post) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:comments).dependent(:destroy) }

    it "rejects slugs with invalid characters" do
      expect(build(:post, slug: "Não Pode")).not_to be_valid
    end
  end

  describe "slug" do
    it "is generated from the title" do
      expect(create(:post, title: "Olá, Mundo Rails!").slug).to eq("ola-mundo-rails")
    end

    it "gets a numeric suffix when taken" do
      create(:post, title: "Repetido")
      expect(create(:post, title: "Repetido").slug).to eq("repetido-2")
    end

    it "is used as URL param" do
      expect(build(:post, slug: "meu-post").to_param).to eq("meu-post")
    end
  end

  describe "publication" do
    it "publish! sets status and published_at" do
      post = create(:post)
      freeze_time do
        post.publish!
        expect(post).to be_published
        expect(post.published_at).to eq(Time.current)
      end
    end

    it "keeps the original publication date when republished" do
      post = create(:post, :published, published_at: 3.days.ago)
      original = post.published_at
      post.unpublish!
      post.publish!
      expect(post.published_at).to eq(original)
    end

    it "unpublish! turns the post back into a draft" do
      post = create(:post, :published)
      post.unpublish!
      expect(post).to be_draft
      expect(post).not_to be_visible
    end
  end

  describe ".visible" do
    it "returns only published posts whose date has arrived" do
      visible = create(:post, :published)
      create(:post) # draft
      create(:post, :scheduled)
      expect(Post.visible).to contain_exactly(visible)
    end
  end

  describe "#tag_list=" do
    it "creates/reuses normalized tags" do
      existing = create(:tag, name: "ruby")
      post = create(:post, tag_list: "Ruby,  rails , rails,")
      expect(post.tags.map(&:name)).to contain_exactly("ruby", "rails")
      expect(post.tags).to include(existing)
      expect(post.tag_list).to eq("ruby, rails")
    end
  end
end
