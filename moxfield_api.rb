require 'net/http'
require 'json'

# Example usage:
# ```
# require_relative './moxfield_api.rb'
# include MoxfieldApi
# wrapup(username)
# ```
# wrapup returns a string like "- cardname      count\\n- cardname   count"
# Then you can find/replace "\\n" with an actual newline to look at the list

module MoxfieldApi
  include JSON

  ARCHIVED_DECKS = [
    "RUGmnath"
  ].freeze

  def request(url)
    uri = URI(url)
    Net::HTTP.get(uri)
  end

  # { "pageNumber"=>1, "pageSize"=>25, "totalResults"=>31, "totalPages"=>2,
  #   "data"=>[{
  #     "publicId"=>"JbTAV1khu0m7FC6xIYe7Ow", # use in deck_url
  #     "name"=>"Riku 2: Modal Boogaloo",
  #     "publicUrl"=>"https://www.moxfield.com/decks/JbTAV1khu0m7FC6xIYe7Ow"
  #     ""
  def get_decks(user="rostrophobia")
    decks_url = "https://api.moxfield.com/v2/users/#{user}/decks"
    JSON.parse(request(decks_url))['data']
  end

  def deck_names(user="rostrophobia")
    decks = get_decks
    decks.map { |deck| "#{deck['name']} #{deck['publicId']}" }
  end

  # { "id", "name",
  #   "mainboard" => { card_name => {...}}
  # }
  def get_deck(public_id="JbTAV1khu0m7FC6xIYe7Ow")
    return {} unless public_id
    deck_url = "https://api.moxfield.com/v2/decks/all/#{public_id}"
    JSON.parse(request(deck_url))
  end

  def cards_by_usage(user = "rostrophobia", forbidden_decks = ARCHIVED_DECKS, filter_type = 'Land')
    decks = get_decks(user)
    card_counts = Hash.new(0)
    decks.each do |deck_info|
      next if forbidden_decks.include?(deck_info["name"])
      deck = get_deck(public_id)
      deck["mainboard"].each do |card_name, card_info|
        next if filter_out(card_info['card'], filter_type)
        card_counts[card_name] += 1
      end
    end

    card_counts
  end

  # Creature — Djinn Monk // Land
  # Basic Land – Island
  def card_types(card_info)
    type_line = card_info['type_line']
    supertypes = type_line.split(/(-|–)/)[0]
    supertypes.strip.split
  end

  def filter_out(card_info, filter_type)
    return false if !filter_type
    card_types(card_info).include?(filter_type)
  rescue => e
    puts card_info['name']
    return false
  end

  def top_thirtyish(cards)
    cutoff = 1
    filtered = filter_cards(cards, cutoff)
    while filtered.size > 50
      cutoff += 1
      filtered = filter_cards(cards, cutoff)
    end

    desc_order = filtered.to_a.sort do |left, right|
      # intentionally backwards to sort descending
      right[1] <=> left[1]
    end

    thirty = desc_order[0..29]
    return thirty if thirty.size < 30 || thirty[-1][1] != desc_order[30][1]

    tie_count = thirty[-1][1]
    desc_order.select do |arr|
      arr[1] >= tie_count
    end
  end

  def filter_cards(cards, cutoff)
    cards.filter do |card_name, count|
      count > cutoff
    end
  end

  def wrapup(user='rostrophobia')
    cards = cards_by_usage(user)
    cards = top_thirtyish(cards)
    pretty_list(cards)
  end

  def pretty_list(cards)
    # Find longest card name to determine spacing
    longest = cards.to_h.keys.sort {|a, b| a.length <=> b.length }[-1]
    line_length = longest.length + 4

    lines = cards.map do |card_and_count|
      card = card_and_count[0]
      count = card_and_count[1].to_s

      "- #{card}" + (" "*(line_length - card.length)) + count
    end

    lines.join('\n')
  end
end
