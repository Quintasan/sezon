require 'sequel'
require 'pry'
require 'gruff'
require 'markdown-tables'

class Array
  def sum
    inject(0.0) { |result, el| result + el[:average_score] }
  end

  def mean
    sum / size
  end
end

DB = Sequel.sqlite("./cartoons.sqlite3")

class Anime < Sequel::Model
  many_to_many :studios,
    left_id: :anime_id,
    right_id: :studio_id
end

class Studio < Sequel::Model
  many_to_many :studios,
    left_id: :studio_id,
    right_id: :anime_id
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

datasets = (2010..2018).map do |i|
  [
    i.to_s,
    Anime.where(year: i).count
  ]
end

graph = Gruff::Bar.new(size=1920).tap do |g|
  g.title = "Liczba chińskich bajek w latach 2008-2018"
  g.minimum_value = 0
  g.maximum_value = 200
  g.show_labels_for_bar_values = true
  datasets.each do |dataset|
    g.data(dataset[0], dataset[1])
  end
end
graph.write("cartoons_distribution.png")

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

res = Anime.group_by(:season, :year).having { max(mean_score) }.map do |result|
  "#{t2(result[:season].to_sym)},#{result[:year]},#{result[:title]},#{result[:mean_score]}"
end
labels = %w[Rok Sezon Bajka Ocena]
data = res.map { |x| [x.split(",")] }.flatten(1)
table = MarkdownTables.make_table(labels, data, is_rows: true)
IO.write("best_cartoons_per_season.md", table)

res = Anime.group(:year).having { max(mean_score) }.map do |result|
  "#{t2(result[:season].to_sym)},#{result[:year]},#{result[:title]},#{result[:mean_score]}"
end
labels = %w[Rok Sezon Bajka Ocena]
data = res.map { |x| [x.split(",")] }.flatten(1)
table = MarkdownTables.make_table(labels, data, is_rows: true)
IO.write("best_cartoons_per_year.md", table)

data = Anime.association_join(:studios).to_hash_groups(:name).map { |key, value| [key, value.length] }.sort { |x, y| x.last <=> y.last }.reverse
labels = ["Studio", "Liczba bajek"]
table = MarkdownTables.make_table(labels, data, is_rows: true)
IO.write("cartoons_per_studio.md", table)

data = Anime.to_hash_groups(:popularity)
dataset = []
(1...100).map do |popularity|
  dataset += data[popularity].map { |r| [r.title, r.popularity] }
end
labels = ["Bajka", "Popularność"]
table = MarkdownTables.make_table(labels, dataset, is_rows: true)
IO.write("cartoons_by_popularity.md", table)

data = Anime.association_join(:studios).to_hash_groups(:name).map { |key, value| [key, value.mean] }.sort { |x, y| x.last <=> y.last }.reverse
labels = ["Studio", "Średnia średnich"]
table = MarkdownTables.make_table(labels, data, is_rows: true)
IO.write("studios_with_best_cartoons.md", table)
