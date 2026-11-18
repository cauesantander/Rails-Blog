module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = Category.alphabetical.left_joins(:posts).group(:id).select("categories.*, COUNT(posts.id) AS posts_count")
      @category = Category.new
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        redirect_to admin_categories_path, notice: "Categoria criada."
      else
        @categories = Category.alphabetical
        render :index, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_categories_path, notice: "Categoria atualizada."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @category.destroy!
      redirect_to admin_categories_path, status: :see_other, notice: "Categoria excluída (posts ficaram sem categoria)."
    end

    private
      def set_category
        @category = Category.find_by!(slug: params[:slug])
      end

      def category_params
        params.expect(category: [ :name ])
      end
  end
end
