require 'recipe_parser'

class Recipe < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :content, presence: true
  validate :validate_recipe, on: [ :create, :update ], if: :content?

  before_validation :extract_title_from_content

  def formatted_prep_time
    format_duration(prep_time)
  end

  def formatted_cook_time
    format_duration(cook_time)
  end

  def formatted_total_time
    return "" unless prep_time.present? && cook_time.present?
    format_duration(prep_time + cook_time)
  end

  private

  def extract_title_from_content
    return if title.present? || content.blank?

    content.to_s.each_line do |line|
      stripped_line = line.strip
      if stripped_line.start_with?('=')
        self.title = stripped_line[1..-1].strip
        break
      end
    end
  end

  def format_duration(total_seconds)
    return "" if total_seconds.to_i <= 0

    seconds = total_seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    parts = []
    parts << "#{hours} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{minutes} minute#{'s' if minutes != 1}" if minutes > 0

    parts.join(' ').presence || "0 minutes"
  end

  def validate_recipe
    RecipeParser.parse(content.to_s)
  rescue ArgumentError => e
    errors.add(:content, e.message)
  end
end
