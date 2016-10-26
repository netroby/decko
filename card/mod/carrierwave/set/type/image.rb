attachment :image, uploader: CarrierWave::ImageCardUploader

include File::SelectedAction

format do
  include File::Format

  view :closed_content do
    _render_core size: :icon
  end

  view :source do
    return card.raw_content if card.web?
    style =
      case
      when @mode == :closed then :icon
      when voo.size         then voo.size.to_sym
      when main?            then :large
      else :medium
      end
    style = :original if style.to_sym == :full
    if style == :original
      card.image.url
    else
      card.image.versions[style].url
    end
  end
end

format :html do
  include File::HtmlFormat

  view :core do
    handle_source do |source|
      if source == "missing"
        "<!-- image missing #{@card.name} -->"
      else
        image_tag source
      end
    end
  end

  def preview
    return unless card.new_card? && !card.preliminary_upload?
    voo.size = :medium
    wrap_with :div, class: "attachment-preview",
                    id: "#{card.attachment.filename}-preview" do
      _render_core
    end
  end

  view :content_changes do |args|
    out = ""
    voo.size = args[:diff_type] == :summary ? :icon : :medium
    if !args[:hide_diff] && args[:action] &&
       (last_change = card.last_change_on(:db_content, before: args[:action]))
      card.selected_action_id = last_change.card_action_id
      out << Card::Content::Diff.render_deleted_chunk(_render_core)
    end
    card.selected_action_id = args[:action].id
    out << Card::Content::Diff.render_added_chunk(_render_core)
    out
  end
end

format :css do
  view :core do
    render_source
  end

  view :content do  # why is this necessary?
    render_core
  end
end

format :file do
  include File::FileFormat

  view :style do # should this be in model?
    ["", "full"].member?(voo.size.to_s) ? :original : voo.size
  end

  def selected_file_version
    style = _render_style(style: voo.size).to_sym
    if style && style != :original
      card.attachment.versions[style]
    else
      card.attachment
    end
  end
end
