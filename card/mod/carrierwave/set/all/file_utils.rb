module ClassMethods
  def update_all_storage_locations
    Card.search(type_id: ["in", FileID, ImageID]).each do |card|
      card.update_storage_location!
    end
  end

  def delete_tmp_files_of_cached_uploads
    draft_actions_with_attachment.each do |action|
      # we don't want to delete uploads in progress
      if older_than_five_days?(action.created_at) && (card = action.card)
        # we don't want to delete uploads in progress
        card.delete_files_for_action action
        action.delete
      end
    end
  end

  def older_than_five_days? time
    Time.now - time > 432_000
  end

  def draft_actions_with_attachment
    Card::Action.find_by_sql(
      "SELECT * FROM card_actions "\
        "INNER JOIN cards ON card_actions.card_id = cards.id "\
        "WHERE cards.type_id IN (#{Card::FileID}, #{Card::ImageID}) "\
        "AND card_actions.draft = true"
    )
  end
end
