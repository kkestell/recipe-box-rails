require "typst"
require "recipe_parser"
require "typst_renderer"
require "recipe_extractor"

class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[ show edit update destroy pdf ]
  allow_unauthenticated_access only: %i[ index show pdf ]

  def index
    base_recipes = Recipe.includes(:user).where(draft: false).order(category: :asc, title: :asc)
    @recipes = RecipeSearchService.new(base_recipes, search_params).call.page(params[:page]).per(20)
    @categories = helpers.recipe_category_options
    @cuisines = helpers.recipe_cuisine_options

    respond_to do |format|
      format.html
      format.turbo_stream { render "shared/recipes_turbo_stream" }
    end
  end

  def show
    @parsed_recipe = RecipeParser.parse(@recipe.content)
  end

  def pdf
    parsed_recipe = RecipeParser.parse(@recipe.content)

    metadata = {
      "title" => @recipe.title,
      "category" => @recipe.category,
      "yield" => @recipe.yield,
      "prep_time" => @recipe.formatted_prep_time,
      "cook_time" => @recipe.formatted_cook_time,
      "cuisine" => @recipe.cuisine,
      "source" => @recipe.source
    }.compact_blank

    typst_source = TypstRenderer.render([ [ parsed_recipe, metadata ] ])
    typst_doc = Typst(body: typst_source).compile(:pdf)

    filename = (@recipe.title.presence || "recipe-#{@recipe.id}").parameterize

    send_data(typst_doc.document, filename: "#{filename}.pdf", type: "application/pdf", disposition: "inline")
  end

  def new
    @recipe = Current.user.recipes.build
  end

  def create
    @recipe = Current.user.recipes.build(recipe_params)
    if @recipe.save
      flash[:notice] = "Recipe created successfully"
      redirect_to @recipe
    else
      flash.now[:alert] = "Recipe could not be created"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recipe.update(recipe_params)
      flash[:notice] = "Recipe updated successfully"
      redirect_to @recipe
    else
      flash.now[:alert] = "Recipe could not be updated"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recipe.destroy
    flash[:notice] = "Recipe deleted successfully"
    redirect_to recipes_path
  end

  def import
    @recipe = Current.user.recipes.build
  end

  def import_from_url
    url = params[:url]

    if url.blank?
      flash.now[:alert] = "Please enter a URL"
      @recipe = Current.user.recipes.build
      return render :import, status: :unprocessable_entity
    end

    begin
      content = RecipeExtractor.fetch_url_content(url)

      if content.blank? || content.start_with?("Error:")
        flash.now[:alert] = "Could not extract recipe from URL: #{content}"
        @recipe = Current.user.recipes.build
        return render :import, status: :unprocessable_entity
      end

      @recipe = Current.user.recipes.build(
        content: content,
        source: url,
        draft: true
      )

      flash.now[:notice] = "Recipe imported successfully! Review and edit as needed before saving."
      render :new
    rescue StandardError => e
      flash.now[:alert] = "Error importing recipe: #{e.message}"
      @recipe = Current.user.recipes.build
      render :import, status: :unprocessable_entity
    end
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    permitted_params = params.require(:recipe).permit(
      :content,
      :category,
      :yield,
      :cuisine,
      :source,
      :prep_time_hours,
      :prep_time_minutes,
      :cook_time_hours,
      :cook_time_minutes,
      :draft
    )

    permitted_params[:prep_time] = convert_time_to_seconds(
      permitted_params.delete(:prep_time_hours),
      permitted_params.delete(:prep_time_minutes)
    )

    permitted_params[:cook_time] = convert_time_to_seconds(
      permitted_params.delete(:cook_time_hours),
      permitted_params.delete(:cook_time_minutes)
    )

    permitted_params
  end

  def convert_time_to_seconds(hours, minutes)
    hours_int = hours.present? ? hours.to_i : 0
    minutes_int = minutes.present? ? minutes.to_i : 0
    return nil if hours_int == 0 && minutes_int == 0
    (hours_int * 3600) + (minutes_int * 60)
  end

  def search_params
    params.permit(:search, :category, :cuisine)
  end
end