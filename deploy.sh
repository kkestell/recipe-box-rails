#!/bin/bash

set -e

ssh kkestell_recipe_box@ssh.nyc1.nearlyfreespeech.net << 'EOF'
  set -e
  cd /home/protected/recipe_box
  git pull
  MAKE=gmake bundle install
  RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
  RAILS_ENV=production bundle exec rails db:migrate
  bundle exec rails restart
EOF
