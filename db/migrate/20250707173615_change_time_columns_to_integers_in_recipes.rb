class ChangeTimeColumnsToIntegersInRecipes < ActiveRecord::Migration[8.0]
  def change
    remove_column :recipes, :prep_time, :string
    remove_column :recipes, :cook_time, :string

    add_column :recipes, :prep_time, :integer
    add_column :recipes, :cook_time, :integer
  end
end
