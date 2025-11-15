release: bundle exec rake db:migrate
web: bundle exec puma -C config/puma.rb
background_jobs: bin/rails solid_queue:start
solid_cable: bin/rails solid_cable