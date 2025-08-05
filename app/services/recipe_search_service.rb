# app/services/recipe_search_service.rb
class RecipeSearchService
  def initialize(recipes_scope, params = {})
    @recipes = recipes_scope
    @params = params
  end

  def call
    apply_search
    apply_category_filter
    apply_cuisine_filter
    apply_title_order
    @recipes
  end

  private

  def apply_search
    return if @params[:search].blank?

    if sqlite_database?
      @recipes = @recipes.where("title LIKE ? COLLATE NOCASE", "%#{@params[:search]}%")
    else
      @recipes = @recipes.where("title ILIKE ?", "%#{@params[:search]}%")
    end
  end

  def apply_category_filter
    return if @params[:category].blank?
    @recipes = @recipes.where(category: @params[:category])
  end

  def apply_cuisine_filter
    return if @params[:cuisine].blank?
    @recipes = @recipes.where(cuisine: @params[:cuisine])
  end

  def apply_title_order
    @recipes = @recipes.order(:title)
  end

  def sqlite_database?
    ActiveRecord::Base.connection.adapter_name == "SQLite"
  end
end