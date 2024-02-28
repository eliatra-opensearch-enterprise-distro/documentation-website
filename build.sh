#!/usr/bin/env bash

rm -rf _site/ .jekyll-*
bundle install
JEKYLL_LINK_CHECKER=internal bundle exec jekyll serve --host localhost --port 4000 --incremental --livereload --open-url
