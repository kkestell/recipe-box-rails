require 'find'

namespace :import do
  desc 'Resets DB and imports all recipes from ~/Dropbox/Recipes for a specific user'
  task recipes: :environment do
    def parse_duration_to_seconds(str)
      return nil if str.blank?
      total_seconds = 0
      str.scan(/(\d+)\s+hour(?:s)?/).each { |m| total_seconds += m[0].to_i * 3600 }
      str.scan(/(\d+)\s+minute(?:s)?/).each { |m| total_seconds += m[0].to_i * 60 }
      total_seconds > 0 ? total_seconds : nil
    end

    puts 'Resetting the database...'
    Rake::Task['db:reset'].invoke
    puts 'Database reset complete.'

    puts 'Creating user: Kyle (kyle@kestell.org)...'
    user = User.find_or_create_by!(email_address: 'kyle@kestell.org') do |u|
      u.name = 'Kyle'
      u.password = 'please'
      u.password_confirmation = 'please'
    end
    puts "User '#{user.name}' created successfully."

    recipes_path = File.expand_path('~/Dropbox/Recipes')

    unless Dir.exist?(recipes_path)
      puts "Error: Recipe directory not found at #{recipes_path}"
      exit
    end

    recipe_files = Dir.glob(File.join(recipes_path, '**', '*.recipe'))
    puts "Found #{recipe_files.count} recipe files in #{recipes_path}. Starting import..."

    ATTRIBUTE_MAP = {
      'Yield' => :yield,
      'Prep Time' => :prep_time,
      'Cook Time' => :cook_time,
      'Category' => :category,
      'Cuisine' => :cuisine,
      'Source' => :source
    }.freeze

    recipe_files.each do |file_path|
      file_content = File.read(file_path)
      frontmatter = {}
      recipe_body = file_content

      if file_content.strip.start_with?('---')
        parts = file_content.split('---', 3)
        if parts.length >= 3
          frontmatter_text = parts[1]
          recipe_body = parts[2].strip

          frontmatter_text.each_line do |line|
            key, value = line.split(':', 2)
            next unless key && value
            frontmatter[key.strip] = value.strip
          end
        end
      end

      recipe_attributes = { content: recipe_body }
      frontmatter.each do |key, value|
        if ATTRIBUTE_MAP.key?(key)
          attribute_name = ATTRIBUTE_MAP[key]
          parsed_value = if [:prep_time, :cook_time].include?(attribute_name)
                           parse_duration_to_seconds(value)
                         else
                           value
                         end
          recipe_attributes[attribute_name] = parsed_value
        end
      end

      recipe = user.recipes.build(recipe_attributes)

      if recipe.save
        puts "  - Imported '#{recipe.title}'"
      else
        puts "  - FAILED to import #{File.basename(file_path)}. Errors: #{recipe.errors.full_messages.join(', ')}"
      end
    end

    puts 'Recipe import finished.'
  end
end
