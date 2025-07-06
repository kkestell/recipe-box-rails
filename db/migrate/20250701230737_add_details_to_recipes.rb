class AddDetailsToRecipes < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :yield, :string
    add_column :recipes, :prep_time, :string
    add_column :recipes, :cook_time, :string
    add_column :recipes, :cuisine, :string
    add_column :recipes, :source, :string
  end
end
