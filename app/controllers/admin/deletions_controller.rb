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
      # Routes are: DELETE /admin/users/:id or DELETE /admin/event_posts/:id
      # So params[:id] will be present, and we infer type from the path
      
      Rails.logger.debug "=== set_deletable Debug ==="
      Rails.logger.debug "Request path: #{request.path}"
      Rails.logger.debug "Request method: #{request.method}"
      Rails.logger.debug "Params: #{params.inspect}"
      Rails.logger.debug "Params[:id]: #{params[:id]} (#{params[:id].class})"
      Rails.logger.debug "Params[:type]: #{params[:type]}"
      Rails.logger.debug "Params keys: #{params.keys.inspect}"
      
      # Validate ID first
      id = params[:id]
      if id.nil? || id.to_s.empty? || id.to_i == 0
        Rails.logger.error "Invalid ID: #{id.inspect}"
        return render json: { 
          error: "Invalid ID parameter", 
          debug: {
            id: id,
            id_class: id.class,
            path: request.path,
            params: params.to_unsafe_h
          }
        }, status: :bad_request
      end
      
      id_int = id.to_i
      
      if request.path.include?('/users/')
        Rails.logger.debug "Inferring type: User (from path)"
        @deletable = User.with_discarded.find(id_int)
      elsif request.path.include?('/event_posts/')
        Rails.logger.debug "Inferring type: EventPost (from path)"
        @deletable = EventPost.with_discarded.find(id_int)
      elsif params[:type] == 'user' || params[:type] == 'User'
        Rails.logger.debug "Inferring type: User (from params)"
        @deletable = User.with_discarded.find(id_int)
      elsif params[:type] == 'event_post' || params[:type] == 'EventPost'
        Rails.logger.debug "Inferring type: EventPost (from params)"
        @deletable = EventPost.with_discarded.find(id_int)
      else
        Rails.logger.error "Could not infer type from path or params"
        render json: { 
          error: "Invalid type. Must be 'user' or 'event_post'", 
          debug: {
            path: request.path,
            params: params.to_unsafe_h
          }
        }, status: :bad_request
        return
      end
      
      Rails.logger.debug "Found deletable: #{@deletable.class.name} ##{@deletable.id}"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Record not found: #{e.message}"
      Rails.logger.error "Path: #{request.path}, Params: #{params.inspect}"
      render json: { 
        error: "Record not found", 
        debug: {
          id: params[:id],
          type: params[:type] || 'inferred from path',
          path: request.path,
          params: params.to_unsafe_h
        }
      }, status: :not_found
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

