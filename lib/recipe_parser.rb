# frozen_string_literal: true

require 'find'

class Step
  attr_accessor :text, :ingredients

  def initialize(text)
    @text = text
    @ingredients = []
  end
end

class Component
  attr_accessor :name, :steps

  def initialize(name = nil)
    @name = name
    @steps = []
  end

  def empty?
    @name.nil? && @steps.empty?
  end
end

class ParsedRecipe
  attr_accessor :title, :components

  def initialize(title, components = [])
    @title = title
    @components = components
  end
end

module RecipeParser
  def self.parse(recipe_text)
    raise ArgumentError, 'Recipe text cannot be empty' if recipe_text.nil? || recipe_text.strip.empty?

    lines = recipe_text.lines.map(&:chomp)
    recipe = nil
    current_component = nil
    current_step = nil

    lines.each do |line|
      next if line.strip.empty?

      recipe ||= ParsedRecipe.new('Untitled Recipe')

      case line
      when /^= /
        recipe.title = line[2..].strip
        if current_component.nil?
          current_component = Component.new
          recipe.components << current_component
        end
        current_step = nil

      when /^\+ /
        recipe.components.pop if current_component&.empty?
        current_step = nil
        current_component = Component.new(line[2..].strip)
        recipe.components << current_component

      when /^# /
        if current_component.nil?
          current_component = Component.new
          recipe.components << current_component
        end
        current_step = Step.new(line[2..].strip)
        current_component.steps << current_step

      when /^\s+- /
        if current_step
          ingredient = line.sub(/^\s+- /, '').strip
          current_step.ingredients << ingredient
        end
      end
    end

    raise ArgumentError, 'Invalid recipe format: No content found.' if recipe.nil?
    recipe.components << Component.new if recipe.components.empty?

    # Validate that at least one ingredient exists in the entire recipe.
    has_ingredients = recipe.components.any? do |component|
      component.steps.any? { |step| !step.ingredients.empty? }
    end
    raise ArgumentError, 'Recipe must contain at least one ingredient.' unless has_ingredients

    recipe
  end

  def self.serialize(recipe)
    output = []

    add_spacer = -> { output << '' if !output.empty? && !output.last.empty? }

    unless recipe.title.empty?
      add_spacer.call
      output << "= #{recipe.title}"
    end

    recipe.components.each do |component|
      is_first_substantive_block = !component.empty? || recipe.components.length > 1
      add_spacer.call if is_first_substantive_block

      output << "+ #{component.name}" if component.name

      component.steps.each do |step|
        add_spacer.call
        output << "# #{step.text}"

        unless step.ingredients.empty?
          add_spacer.call
          step.ingredients.each { |ingredient| output << "  - #{ingredient}" }
        end
      end
    end

    output.join("\n")
  end
end
