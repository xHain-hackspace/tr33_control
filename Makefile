export SERIAL_PORT = ttyUSB0
export CACHE_PERSIST_DIR = $(HOME)/.tr33_cache

init: deps-get assets-install

console:
	iex -S mix phx.server

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
