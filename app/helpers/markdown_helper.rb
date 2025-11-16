require "kramdown-parser-gfm"

module MarkdownHelper
  ALLOWED_TAGS = %w[
    p br pre code strong em del ins ul ol li blockquote hr
    table thead tbody tr th td span div img a
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href title rel target src alt class].freeze

  def render_markdown(text)
    return "" if text.blank?

    html = render_kramdown(text)
    sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  rescue StandardError => e
    Rails.logger.error("Markdown render failed: #{e.message}")
    simple_format(text)
  end

  private

  def render_kramdown(text)
    Kramdown::Document
      .new(text, input: "GFM", entity_output: :symbolic, hard_wrap: false)
      .to_html
  end
end
