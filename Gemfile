source "https://rubygems.org"

gem "base64"
gem "bigdecimal"

gem "jekyll", ENV["JEKYLL_VERSION"]
gem "kramdown-parser-gfm"

group :jekyll_plugins do
  gem "jekyll-algolia"
  gem "jekyll-feed"
  gem "jekyll-gist"
  gem "jekyll-include-cache"
  gem "jekyll-paginate"
  gem "jekyll-remote-theme"
  gem "jekyll-sitemap"
  gem "jemoji" if ENV["REQUIRE_JEMOJI"]
end

gem "memory_profiler"

if Gem.win_platform?
  gem "tzinfo-data"  # Timezone files for Windows.
  gem "wdm"          # Performance-booster for watching directories on Windows.
end

gem "webrick", "~> 1.7"
