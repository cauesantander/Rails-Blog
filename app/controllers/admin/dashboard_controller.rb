module Admin
  class DashboardController < BaseController
    def show
      @counts = {
        published_posts: Post.published.count,
        draft_posts: Post.draft.count,
        comments: Comment.count,
        hidden_comments: Comment.hidden.count,
        users: User.count,
        confirmed_subscribers: Subscriber.confirmed.count,
        pending_subscribers: Subscriber.pending.count
      }
      @recent_campaigns = Campaign.recent.limit(5)
      @queues = QueueStats.snapshot
    end
  end
end
