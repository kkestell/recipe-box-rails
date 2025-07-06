# app/controllers/users/recipes_controller.rb
class Users::RecipesController < ApplicationController
  # Allow unauthenticated access to the index, and both cookbook GET/POST actions
  allow_unauthenticated_access only: %i[ index cookbook create_cookbook ]

  def index
    @user = User.find(params[:user_id])
    base_recipes = @user.recipes.includes(:user)
    @recipes = RecipeSearchService.new(base_recipes, search_params).call.page(params[:page]).per(50)
    @categories = helpers.recipe_category_options
    @cuisines = helpers.recipe_cuisine_options

    respond_to do |format|
      format.html
      format.turbo_stream { render 'shared/recipes_turbo_stream' }
    end
  end

  # GET /users/:user_id/recipes/cookbook
  # Displays a form for the user to enter cookbook title and subtitle.
  def cookbook
    @user = User.find(params[:user_id])
    # No specific data fetching is needed here, just prepare for the form.
  end

  # POST /users/:user_id/recipes/cookbook
  # Generates the PDF cookbook based on form input.
  def create_cookbook
    @user = User.find(params[:user_id])

    # Get title and subtitle from params, applying default values if blank.
    # If params[:title] is blank, it defaults to "{user.name}'s Cookbook".
    # If params[:subtitle] is blank, it defaults to nil.
    cookbook_title = params[:title].presence || "#{@user.name.presence || 'User'}'s Cookbook"
    cookbook_subtitle = params[:subtitle].presence

    # Fetch all recipes for the user, ordered by category and title for a structured cookbook.
    recipes = @user.recipes.order(:category, :title)

    # Prepare recipes and their metadata for the TypstRenderer.
    recipes_with_meta = recipes.map do |recipe|
      parsed_recipe = RecipeParser.parse(recipe.content)
      metadata = {
        'title' => recipe.title,
        'category' => recipe.category,
        'yield' => recipe.yield,
        'prep_time' => recipe.prep_time,
        'cook_time' => recipe.cook_time,
        'cuisine' => recipe.cuisine,
        'source' => recipe.source
      }.compact_blank # Removes nil and empty string values from the hash
      [parsed_recipe, metadata]
    end

    # Use the TypstRenderer to generate the Typst source code for the entire cookbook.
    typst_source = TypstRenderer.render(
      recipes_with_meta,
      title: cookbook_title,
      subtitle: cookbook_subtitle # Pass the user-provided or default subtitle
    )

    # Compile the Typst source into a PDF document.
    typst_doc = Typst(body: typst_source).compile(:pdf)

    # Determine the filename for the PDF, based on the cookbook title.
    filename = (cookbook_title.parameterize.presence || "cookbook-#{@user.id}").parameterize

    # Send the generated PDF data to the browser.
    send_data(
      typst_doc.document,
      filename: "#{filename}.pdf",
      type: "application/pdf",
      disposition: "inline" # Displays the PDF directly in the browser
    )
  end

  private

  def search_params
    params.permit(:search, :category, :cuisine)
  end
end