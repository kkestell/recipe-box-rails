class AddDraftToRecipes < ActiveRecord::Migration[8.0]
  def change
    change_table :recipes do |t|
      t.boolean :draft, default: false, null: false
    end
  end
end
