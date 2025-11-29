module Admin
  class EventCategoriesController < AdminBaseController
    before_action :set_event_category, only: [:show, :update, :destroy]

    def index
      @categories = EventCategory.order(:name)
      render json: @categories
    end

    def show
      render json: @category
    end

    def create
      @category = EventCategory.new(event_category_params)

      if @category.save
        render json: @category, status: :created
      else
        render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @category.update(event_category_params)
        render json: @category
      else
        render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      if @category.event_posts.exists?
        render json: { error: "Cannot delete category with existing events. Move or delete events first." }, status: :unprocessable_entity
      else
        @category.destroy
        render json: { success: true, message: "Category deleted" }
      end
    end

    private

    def set_event_category
      @category = EventCategory.find(params[:id])
    end

    def event_category_params
      params.require(:event_category).permit(:name, :color)
    end
  end
end
