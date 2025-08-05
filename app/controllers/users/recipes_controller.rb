class Users::RecipesController < ApplicationController
  allow_unauthenticated_access only: %i[ index cookbook create_cookbook ]

  def index
    @user = User.find(params[:user_id])
    base_recipes = @user.recipes.includes(:user)
    @recipes = RecipeSearchService.new(base_recipes, search_params).call.page(params[:page]).per(50)
    @categories = helpers.recipe_category_options
    @cuisines = helpers.recipe_cuisine_options

    respond_to do |format|
      format.html
      format.turbo_stream { render "shared/recipes_turbo_stream" }
    end
  end

  def cookbook
    @user = User.find(params[:user_id])
  end

  def create_cookbook
    @user = User.find(params[:user_id])

    cookbook_title = params[:title].presence || "#{@user.name.presence || 'User'}'s Cookbook"
    cookbook_subtitle = params[:subtitle].presence

    recipes = @user.recipes.order(:category, :title)

    recipes_with_meta = recipes.map do |recipe|
      parsed_recipe = RecipeParser.parse(recipe.content)
      metadata = {
        "title" => recipe.title,
        "category" => recipe.category,
        "yield" => recipe.yield,
        "prep_time" => recipe.formatted_prep_time,
        "cook_time" => recipe.formatted_cook_time,
        "cuisine" => recipe.cuisine,
        "source" => recipe.source
      }.compact_blank
      [ parsed_recipe, metadata ]
    end

    typst_source = TypstRenderer.render(recipes_with_meta, title: cookbook_title, subtitle: cookbook_subtitle)
    typst_doc = Typst(body: typst_source).compile(:pdf)

    filename = (cookbook_title.parameterize.presence || "cookbook-#{@user.id}").parameterize

    send_data(typst_doc.document, filename: "#{filename}.pdf", type: "application/pdf", disposition: "inline")
  end

  private

  def search_params
    params.permit(:search, :category, :cuisine)
  end
end