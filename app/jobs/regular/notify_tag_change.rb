# frozen_string_literal: true

module Jobs
  class NotifyTagChange < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])

      if post&.topic&.visible?
        post_alerter = PostAlerter.new
        post_alerter.notify_post_users(post, excluded_users(args), include_topic_watchers: !post.topic.private_message?, include_category_watchers: false)
        post_alerter.notify_first_post_watchers(post, post_alerter.tag_watchers(post.topic))
      end
    end

    private

    def excluded_users(args)
      if !args[:diff_tags] || !all_tags_in_hidden_groups?(args)
        return User.where(id: args[:notified_user_ids])
      end
      group_users_join = DB.sql_fragment("LEFT JOIN group_users ON group_users.user_id = users.id AND group_users.group_id IN (:group_ids)", group_ids: tag_group_ids(args))
      condition = DB.sql_fragment("group_users.id IS NULL OR users.id IN (:notified_user_ids)", notified_user_ids: args[:notified_user_ids])
      User.joins(group_users_join).where(condition)
    end

    def all_tags_in_hidden_groups?(args)
      Tag
        .where(name: args[:diff_tags])
        .joins(tag_groups: :tag_group_permissions)
        .where.not(tag_group_permissions: { group_id: 0 })
        .distinct
        .count == args[:diff_tags].count
    end

    def tag_group_ids(args)
      Tag.where(name: args[:diff_tags]).joins(tag_groups: :tag_group_permissions).pluck("tag_group_permissions.group_id")
    end
  end
end
