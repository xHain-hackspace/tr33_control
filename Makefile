export SERIAL_PORT = ttyUSB0

run: 
	iex -S mix phx.server

setup: deps-get assets-install

deps-get:
	mix deps.get

deps-update: assets-update
	mix deps.update --all

assets-install:  
	npm install --prefix assets

assets-outdated:
	npm outdated --prefix assets

# https://www.carlrippon.com/upgrading-npm-dependencies/
assets-update:
	npm update --prefix assets

assets-release:
	MIX_ENV=prod mix assets.deploy

release: export MIX_ENV=prod
release: deps-get
	mix release --overwrite


