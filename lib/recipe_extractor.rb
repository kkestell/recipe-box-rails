require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'cgi'

class RecipeExtractor
  def self.extract_recipe_text(doc)
    doc.css('*').each do |container|
      has_ingredients = container.text.downcase.include?('ingredients')
      has_instructions = container.text.downcase.match?(/instructions|directions/)

      if has_ingredients && has_instructions
        return container.text.strip.gsub(/\s+/, ' ')
      end
    end
    nil
  end

  def self.fetch_url_content(url)
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      return "Error: HTTP #{response.code} #{response.message}"
    end

    doc = Nokogiri::HTML(response.body)
    recipe_json = extract_recipe_json(doc)

    if recipe_json
      transformed_json = transform_recipe_json(recipe_json)
      return format_as_recipe_box(transformed_json)
    end

    recipe_text = extract_recipe_text(doc)
    return recipe_text || ""

  rescue StandardError => e
    "Error: #{e.message}"
  end

  def self.extract_recipe_json(doc)
    scripts = doc.css('script[type="application/ld+json"]')

    scripts.each do |script|
      next unless script.content

      begin
        data = JSON.parse(script.content)

        if data.is_a?(Array)
          data.each do |item|
            type = item['@type']
            if type == 'Recipe' || (type.is_a?(Array) && type.include?('Recipe'))
              return item
            end
          end
        else
          type = data['@type']
          if type == 'Recipe' || (type.is_a?(Array) && type.include?('Recipe'))
            return data
          end
        end
      rescue JSON::ParserError => e
        puts "Failed to parse JSON: #{e.message}"
        next
      end
    end

    nil
  rescue StandardError => e
    puts "Request failed: #{e.message}"
    nil
  end

  def self.transform_recipe_json(recipe)
    {
      title: get_title(recipe),
      description: get_description(recipe),
      url: get_url(recipe),
      ingredient_groups: [
        {
          title: "",
          ingredients: get_ingredients(recipe)
        }
      ],
      instruction_groups: get_instruction_groups(recipe)
    }
  end

  def self.get_title(recipe)
    val = recipe['name']
    return nil unless val

    val = CGI.unescapeHTML(val)
    val.strip
  end

  def self.get_url(recipe)
    url = recipe['url']
    return url if url.is_a?(String)

    main_entity = recipe['mainEntityOfPage']
    if main_entity.is_a?(Hash)
      return main_entity['@id']
    end

    id = recipe['@id']
    return id if id&.start_with?('http')

    nil
  end

  def self.get_description(recipe)
    val = recipe['description']
    return nil unless val

    val = CGI.unescapeHTML(val)
    val = normalize_fractions(val)
    val = normalize_temperatures(val)
    val = collapse_whitespace(val)
    val.strip
  end

  def self.get_ingredients(recipe)
    ingredients = recipe['recipeIngredient']
    return nil unless ingredients

    if ingredients.is_a?(Array)
      ingredients.map { |i| clean_text(i) }
    else
      nil
    end
  end

  def self.get_instruction_groups(recipe)
    instructions_element = recipe['recipeInstructions']
    instruction_groups = []

    if instructions_element.is_a?(Array)
      if instructions_element.all? { |i| i.is_a?(String) }
        instructions = instructions_element.map { |i| clean_text(i) }
        instruction_groups << { title: "", instructions: instructions }
      elsif instructions_element.all? { |i| i.is_a?(Hash) }
        if instructions_element.all? { |i| i['@type'] == 'HowToStep' }
          instructions = instructions_element.filter_map do |i|
            text = i['text'] || i['name']
            clean_text(text) if text
          end
          instruction_groups << { title: "", instructions: instructions }
        elsif instructions_element.all? { |i| i['@type'] == 'HowToSection' }
          instructions_element.each do |group|
            group_name = group['name']
            item_list_element = group['itemListElement']

            if item_list_element
              group_instructions = item_list_element.filter_map do |i|
                clean_text(i['text']) if i['text']
              end
              instruction_groups << { title: group_name, instructions: group_instructions }
            end
          end
        end
      end
    end

    instruction_groups.empty? ? nil : instruction_groups
  end

  private

  def self.clean_text(text)
    return nil unless text

    text = CGI.unescapeHTML(text)
    text = normalize_fractions(text)
    text = normalize_temperatures(text)
    text = collapse_whitespace(text)
    text.strip
  end

  def self.normalize_fractions(text)
    text.gsub('½', '1/2')
        .gsub('⅓', '1/3')
        .gsub('⅔', '2/3')
        .gsub('¼', '1/4')
        .gsub('¾', '3/4')
        .gsub('⅛', '1/8')
        .gsub('⅜', '3/8')
        .gsub('⅝', '5/8')
        .gsub('⅞', '7/8')
  end

  def self.normalize_temperatures(text)
    text.gsub(/(\d+)\s*°\s*F/, '\1°F')
        .gsub(/(\d+)\s*°\s*C/, '\1°C')
  end

  def self.collapse_whitespace(text)
    text.gsub(/\s+/, ' ')
  end

  def self.format_as_recipe_box(recipe_data)
    output = []

    # Title
    if recipe_data[:title]
      output << "= #{recipe_data[:title]}"
      output << ""
    end

    # Ingredients
    if recipe_data[:ingredient_groups]&.any?
      output << "# Gather all ingredients."
      output << ""

      recipe_data[:ingredient_groups].each do |group|
        if group[:ingredients]&.any?
          group[:ingredients].each do |ingredient|
            output << "  - #{ingredient}"
          end
        end
      end
      output << ""
    end

    # Instructions
    if recipe_data[:instruction_groups]&.any?
      recipe_data[:instruction_groups].each do |group|
        if group[:instructions]&.any?
          group[:instructions].each do |instruction|
            output << "# #{instruction}"
            output << ""
          end
        end
      end
    end

    output.join("\n").strip
  end
end

def main
  url = "https://www.allrecipes.com/krispy-kreme-banana-pudding-recipe-11765910"
  puts "Fetching recipe from: #{url}"
  puts "=" * 50

  result = RecipeExtractor.fetch_url_content(url)
  puts result
end

main if __FILE__ == $0