require "typst"
require "recipe_parser"
require "typst_renderer"

class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[ show edit update destroy pdf ]
  allow_unauthenticated_access only: %i[ index show pdf ]

  def index
    @recipes = Recipe.includes(:user).page(params[:page]).per(50)

    respond_to do |format|
      format.html
      format.turbo_stream { render 'shared/recipes_turbo_stream' }
    end
  end

  def show
    @parsed_recipe = RecipeParser.parse(@recipe.content)
  end

  def pdf
    # Parse the recipe from its stored content.
    parsed_recipe = RecipeParser.parse(@recipe.content)

    # Extract metadata from the ActiveRecord model into a hash.
    metadata = {
      'title' => @recipe.title,
      'category' => @recipe.category,
      'yield' => @recipe.yield,
      'prep_time' => @recipe.prep_time,
      'cook_time' => @recipe.cook_time,
      'cuisine' => @recipe.cuisine,
      'source' => @recipe.source
    }.compact_blank

    # Package the recipe and its metadata into a pair.
    # The renderer expects an array of these pairs.
    recipes_with_meta = [[parsed_recipe, metadata]]

    # Use the renderer to generate Typst source.
    typst_source = TypstRenderer.render(recipes_with_meta)

    # Compile the Typst source into a PDF document.
    typst_doc = Typst(body: typst_source).compile(:pdf)

    # Determine the filename from the recipe title.
    filename = (@recipe.title.presence || "recipe-#{@recipe.id}").parameterize

    # Send the generated PDF data to the browser.
    send_data(
      typst_doc.document,
      filename: "#{filename}.pdf",
      type: "application/pdf",
      disposition: "inline"
    )
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

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(
      :content,
      :category,
      :yield,
      :prep_time,
      :cook_time,
      :cuisine,
      :source,
      :title
    )
  end
end
