# frozen_string_literal: true

module TypstRenderer
  def self.render(recipes_with_meta, title: nil, subtitle: nil, title_heading_level: 1)
    typst = []
    typst << typst_header

    if recipes_with_meta.count == 1
      recipe, metadata = recipes_with_meta.first
      typst << render_single_recipe(recipe, metadata || {}, title_heading_level: title_heading_level)
    else
      typst.concat(render_cookbook(recipes_with_meta, title: title, subtitle: subtitle))
    end

    typst.join("\n\n")
  end

  class << self
    private

    def render_cookbook(recipes_with_meta, title:, subtitle:)
      typst = []

      if title.present? || subtitle.present?
        typst << "#v(5cm)"
        typst << "#align(center)[#text(size: 22pt)[#heading(level: 1, outlined: false)[#{title}]]]"
        typst << "#v(1cm)"
        typst << "#align(center)[#heading(level: 2, outlined: false)[#{subtitle}]]" if subtitle.present?
        typst << "#pagebreak()"
      end

      typst << "#align(center)[#heading(level: 1, outlined: false)[Contents]]"
      typst << "#v(1cm)"
      typst << "#outline(title: none, depth: 2)"
      typst << "#pagebreak()"
      typst << "#counter(page).update(1)"

      recipes_by_category = recipes_with_meta.group_by { |_, meta| meta['category'].presence || 'Uncategorized' }.sort.to_h

      recipes_by_category.each_with_index do |(category, cat_recipes), cat_idx|
        typst << "#v(5cm)" # Added vertical space before category heading
        typst << "#align(center)[#heading(level: 1)[#{category}]]"
        typst << "#pagebreak()"

        cat_recipes.each_with_index do |(recipe, meta), rec_idx|
          typst << render_single_recipe(recipe, meta, title_heading_level: 2)
          typst << "#pagebreak()" if rec_idx < cat_recipes.count - 1 || cat_idx < recipes_by_category.count - 1
        end
      end

      typst
    end

    def render_single_recipe(recipe, metadata, title_heading_level: 1)
      typst = []
      metadata ||= {}

      footer_content = if metadata['source'].present?
                         "#text(8pt)[#{fancy(metadata['source'])}] #h(1fr) #text(8pt, [#counter(page).display() / #counter(page).final().at(0)])"
                       else
                         "#h(1fr) #text(8pt, [#counter(page).display() / #counter(page).final().at(0)]) #h(1fr)"
                       end
      typst << "#set page(footer: context [#{footer_content}])"

      title = metadata['title'].presence || 'Untitled Recipe'

      metadata_order = %w[yield prep_time cook_time category cuisine]
      grid_meta = metadata.except('title', 'source').compact_blank

      sorted_meta = grid_meta.to_a.sort_by do |k, _|
        metadata_order.index(k.to_s) || metadata_order.length
      end.to_h

      typst << (sorted_meta.any? ? render_title_with_metadata_grid(title, sorted_meta, title_heading_level) : "#heading(level: #{title_heading_level})[#{title}]")

      typst << "#v(1.5em)\n#line(length: 100%, stroke: 0.5pt)\n#v(1.5em)"

      recipe.components.each_with_index do |component, index|
        typst << "=== #{component.name}\n#v(1em)" if component.name.present?

        component.steps.each_with_index do |step, step_index|
          typst << render_step(step, step_index)
          typst << "#v(1em)" if step_index < component.steps.count - 1
        end
        typst << "#v(3em)" if index < recipe.components.count - 1
      end

      typst.join("\n\n")
    end

    def render_title_with_metadata_grid(title, metadata, title_heading_level)
      <<~TYPST
        #grid(
          columns: (1fr, auto),
          gutter: 2em,
          align: horizon,
          [#heading(level: #{title_heading_level})[#{title}]],
          [
            #align(right)[
              #block[
                #set text(size: 9pt)
                #{render_metadata_subgrid(metadata)}
              ]
            ]
          ]
        )
      TYPST
    end

    def render_metadata_subgrid(metadata)
      metadata.to_a.each_slice(5).map do |chunk|
        keys = chunk.map { |k, _| "[#align(center)[#text(weight: \"bold\")[#{k.humanize.titleize}]]]" }
        values = chunk.map { |_, v| "[#align(center)[#{v.to_s.gsub('"', '\"')}]]" }

        (5 - chunk.length).times do
          keys << "[]"
          values << "[]"
        end

        all_items = keys + values

        "#grid(columns: (auto, auto, auto, auto, auto), column-gutter: 1.5em, row-gutter: 0.75em, #{all_items.join(', ')})"
      end.join("\n#v(1em)\n")
    end

    def render_step(step, index)
      ingredient_list = step.ingredients.map { |i| "[#{fancy(i)}]" }.join(", ")
      <<~TYPST
        #grid(
          columns: (2fr, 1fr),
          gutter: 3em,
          [
            #enum.item(#{index + 1})[#{fancy(step.text)}]
          ],
          [
            #if #{step.ingredients.any?} {
              block(
                breakable: false,
                list(
                  spacing: 1em,
                  #{ingredient_list}
                )
              )
            }
          ]
        )
      TYPST
    end

    def fancy(text)
      return "" if text.blank?
      # Corrected the goofy quoting here
      text.gsub("°F", " °F").gsub(/(?<=\d)\/(?=\d)/, "⁄").gsub(/(?<=\d)x(?=\d)/, "×").gsub(/(?<=\d)-(?=\d)/, "–")
    end

    def typst_header
      <<~TYPST
        #set list(spacing: 0.65em)
        #set text(font: "Libertinus Serif", size: 11pt)
        #set page("us-letter", margin: (top: 0.75in, bottom: 1in, left: 0.75in, right: 0.75in))
        #set enum(spacing: 1.5em)
      TYPST
    end
  end
end
