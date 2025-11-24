module Admin
  class DeletionsController < AdminBaseController
    before_action :set_deletable, only: [:preview, :destroy, :restore]

    # GET /admin/users/:id/deletion_preview
    # GET /admin/event_posts/:id/deletion_preview
    def preview
      render json: {
        type: @deletable.class.name,
        id: @deletable.id,
        title: deletable_title,
        will_delete: @deletable.deletion_preview,
        confirmation_required: true
      }
    end

    # DELETE /admin/users/:id
    # DELETE /admin/event_posts/:id
    def destroy
      # Validate confirmation
      unless params[:confirmation] == "DELETE"
        return render json: { error: "Must type DELETE to confirm" }, status: :unprocessable_entity
      end

      # Check permissions
      if @deletable.is_a?(User) && !current_user.can_delete_user?(@deletable)
        return render json: { error: "Cannot delete this user" }, status: :forbidden
      elsif @deletable.is_a?(EventPost) && !current_user.can_delete_event?(@deletable)
        return render json: { error: "Cannot delete this event" }, status: :forbidden
      end

      deletion_reason = params[:reason] || "Deleted by admin"
      
      # Capture preview before deletion
      preview = @deletable.deletion_preview

      # Log the deletion attempt immediately (before async job)
      AdminAuditLog.create!(
        admin_user: current_user,
        action: 'delete',
        target_type: @deletable.class.name,
        target_id: @deletable.id,
        metadata: { reason: deletion_reason, preview: preview, async: true, queued_at: Time.current },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      # Queue the actual deletion as a background job
      # This allows the request to return immediately while deletion happens async
      AdminDeletionJob.perform_later(
        @deletable.class.name,
        @deletable.id,
        current_user.id,
        deletion_reason
      )

      render json: {
        success: true,
        message: "#{@deletable.class.name} deletion queued. It will be processed in the background.",
        grace_period_ends: 30.days.from_now,
        async: true
      }
    end

    # POST /admin/restore/:type/:id
    def restore
      # Discard's restore (undiscard) - handle cascading manually
      if @deletable.undiscard
        # If it's a User, restore their events
        if @deletable.is_a?(User)
          @deletable.organized_events.with_discarded.discarded.each(&:undiscard)
        end
        # If it's an EventPost, restore its registrations
        if @deletable.is_a?(EventPost)
          @deletable.event_registrations.with_discarded.discarded.each(&:undiscard)
        end

        AdminAuditLog.create!(
          admin_user: current_user,
          action: 'restore',
          target_type: @deletable.class.name,
          target_id: @deletable.id,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )

        render json: { success: true, message: "#{@deletable.class.name} restored" }
      else
        render json: { error: "Restore failed" }, status: :unprocessable_entity
      end
    end

    private

    def set_deletable
      # Handle routes like /admin/users/:id or /admin/event_posts/:id
      if params[:user_id] || (params[:type] == 'user')
        id = params[:id] || params[:user_id]
        @deletable = User.with_discarded.find(id)
      elsif params[:event_post_id] || (params[:type] == 'event_post')
        id = params[:id] || params[:event_post_id]
        @deletable = EventPost.with_discarded.find(id)
      else
        # Try to infer from controller path
        if request.path.include?('/users/')
          @deletable = User.with_discarded.find(params[:id])
        elsif request.path.include?('/event_posts/')
          @deletable = EventPost.with_discarded.find(params[:id])
        else
          render json: { error: "Invalid type. Must be 'user' or 'event_post'" }, status: :bad_request
        end
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Record not found" }, status: :not_found
    end

    def deletable_title
      if @deletable.respond_to?(:name)
        @deletable.name
      elsif @deletable.respond_to?(:title)
        @deletable.title
      else
        "#{@deletable.class.name} ##{@deletable.id}"
      end
    end
  end
end

