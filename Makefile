export SERIAL_PORT = ttyUSB0
export CACHE_PERSIST_DIR = $(HOME)/.tr33_cache

console:
	iex -S mix phx.server

deps-get:
	mix deps.get

deps-update:
	mix deps.update --all

assets-install:
  # rm -rf assets/node_modules
	npm install --prefix assets

assets-outdated:
	npm outdated --prefix assets

# https://www.carlrippon.com/upgrading-npm-dependencies/
assets-update:
	npm update --prefix assets
	cd assets && npm install --force phoenix_live_view 	

assets-build:
	npm --prefix assets run deploy && mix phx.digest
