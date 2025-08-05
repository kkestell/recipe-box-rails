module RecipesHelper
  NARROW_NO_BREAK_SPACE = "\u202f"
  FRACTION_SLASH = "\u2044"
  MULTIPLICATION_SIGN = "\u00d7"
  EN_DASH = "\u2013"

  def fancy(text)
    return "" if text.nil?
    text = text.to_s

    text = text.gsub(/(\d+)°F/, '\1' + NARROW_NO_BREAK_SPACE + '°F')
    text = text.gsub(/(\d+) (\d+\/\d+)/, '\1' + NARROW_NO_BREAK_SPACE + '\2')
    text = text.gsub(/(?<=\d)\/(?=\d)/, FRACTION_SLASH)
    text = text.gsub(/(?<=\d)x(?=\d)/, MULTIPLICATION_SIGN)
    text = text.gsub(/(?<=\d)-(?=\d)/, EN_DASH)

    text
  end
end