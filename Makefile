local:
	bundle exec jekyll build -d _site -s src --config _config.yml,_config-local.yml

serve-local:
	bundle exec jekyll serve -d _site -s src --config _config.yml,_config-local.yml
