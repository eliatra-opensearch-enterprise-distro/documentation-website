#!/usr/bin/env bash

# from your command line
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

rm -rf _site/ .jekyll-*
bundle install
JEKYLL_LINK_CHECKER=internal bundle exec jekyll serve --host localhost --port 4000 --incremental --livereload --open-url
