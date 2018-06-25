require 'graphql/client'
require 'graphql/client/http'
require 'sequel'
require 'pry'

DB = Sequel.sqlite("./cartoons.sqlite3")

DB.create_table :animes do
  primary_key :id
  String :title, uniq: true, null: false
  String :season, null: false
  Integer :year, null: false
  Integer :mean_score
  Integer :average_score
  Integer :popularity
  String :score_distribution
end

DB.create_table :studios do
  primary_key :id
  String :name, uniq: true, null: false
end

DB.create_table :animes_studios do
  primary_key :id
  foreign_key :anime_id, :animes
  foreign_key :studio_id, :studios
end

class Anime < Sequel::Model
  many_to_many :studios
end

class Studio < Sequel::Model
  many_to_many :animes
end

module AniList
  HTTP = GraphQL::Client::HTTP.new("https://graphql.anilist.co") do
    def headers(context)
      {
          "User-Agent": "statistics scraper (anilist.co@quintasan.pl)"
      }
    end
  end

  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end

AnimeBySeasonAndYearQuery = AniList::Client.parse <<-'GRAPHQL'
query($page: Int, $year: Int, $season: MediaSeason) {
  Page(page: $page, perPage: 50) {
    pageInfo {
      currentPage
      lastPage
      hasNextPage
    }
    media (type: ANIME, season: $season, seasonYear: $year) {
      id
      title {
        romaji
      }
      averageScore
      meanScore
      popularity
      stats {
        scoreDistribution {
          score
          amount
        }
      }
      studios(isMain: true) {
        nodes {
          name
        }
      }
    }
  }
}
GRAPHQL

def scrape(season, year)
  page = 1

  result = AniList::Client.query(
    AnimeBySeasonAndYearQuery,
    variables: {
      year: year,
      season: season
    }
  )

  animes = result.data.page.media.map do |anime|
    [anime.title.romaji, season, year, anime.average_score, anime.mean_score, anime.popularity]
  end

  studios = result.data.page.media.map do |anime|
    anime.studios.nodes.map(&:name).map { |studio| [studio] }
  end

  anime_studios = result.data.page.media.map do |anime|
    [anime.title.romaji, anime.studios.nodes.map(&:name)]
  end

  studios.reject!(&:empty?).flatten!.map! { |s| [s] }

  while result.data.page.page_info.has_next_page
    page += 1
    result = AniList::Client.query(
      AnimeBySeasonAndYearQuery,
      variables: {
        year: year,
        season: season,
        page: page
      }
    )

    animes += result.data.page.media.map do |anime|
        [anime.title.romaji, season, year, anime.average_score, anime.mean_score, anime.popularity]
    end

    sts = result.data.page.media.map do |anime|
      anime.studios.nodes.map(&:name).map { |studio| [studio] }
    end
    sts.reject!(&:empty?)&.flatten!&.map! { |s| [s] }

    studios += sts

    anime_studios += result.data.page.media.map do |anime|
      [anime.title.romaji, anime.studios.nodes.map(&:name)]
    end
  end

  # Import to database
  DB[:animes].import(Anime.columns.drop(1), animes)
  DB[:studios].import(Studio.columns.drop(1), studios)

  # Restore relations
  animes.each do |anime|
    a = Anime.first!(title: anime)
    anime_studios.select { |x| x[0].eql?(a.title) }.first.last.each do |studio|
      a.add_studio(Studio.first(name: studio))
    end
    a.save
  end
end

argss = (2008..2018).map do |year|
  %w(WINTER SPRING SUMMER FALL).zip([year].cycle(4))
end

argss.each do |args|
  args.each do |arg|
    puts "Scraping #{arg[0]} #{arg[1]}"
    scrape(arg[0], arg[1])
    sleep 10
  end
end

pry
