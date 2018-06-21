require 'sequel'
require 'pry'
require 'gruff'
require 'markdown-tables'

DB = Sequel.sqlite("./cartoons.sqlite3")

class Anime < Sequel::Model
  many_to_many :studios
end

class Studio < Sequel::Model
  many_to_many :animes
end

def t(arg)
  return {
    "WINTER": "zimowym",
    "SPRING": "wiosennym",
    "SUMMER": "letnim",
    "FALL": "jesiennym"
  }[arg]
end

def t2(arg)
  {
    "WINTER": "Zima",
    "SPRING": "Wiosna",
    "SUMMER": "Lato",
    "FALL": "Jesień",
  }[arg]
end

# Cartoons in each season per year

%w[WINTER SPRING SUMMER FALL].each do |season|

  datasets = Anime.where(season: season).group_and_count(:season, :year).map do |result|
    [
      "#{t2(result[:season].to_sym)} #{result[:year]}",
      result[:count]
    ]
  end

  graph = Gruff::Bar.new(size=1920).tap do |g|
    g.title = "Liczba chińskich bajek w sezonie #{t(season.to_sym)}"
    g.minimum_value = 0
    g.maximum_value = 200
    g.show_labels_for_bar_values = true
    datasets.each do |dataset|
      g.data(dataset[0], dataset[1])
    end

  end

  graph.write("cartoons_in_#{season.downcase}.png")
end

# Table

res = Anime.group_by(:season, :year).having { max(average_score) }.map do |result|
  "#{t2(result[:season].to_sym)},#{result[:year]},#{result[:title]},#{result[:average_score]}"
end
labels = %w[Rok Sezon Bajka Ocena]
data = res.map { |x| [x.split(",")] }.flatten(1)
table = MarkdownTables.make_table(labels, data, is_rows: true)
