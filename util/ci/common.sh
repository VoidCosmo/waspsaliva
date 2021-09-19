#!/bin/bash -e

# Linux build only
install_linux_deps() {
	local pkgs=(libirrlicht-dev cmake libbz2-dev libpng-dev \
		libjpeg-dev libxxf86vm-dev libgl1-mesa-dev libsqlite3-dev \
		libhiredis-dev libogg-dev libgmp-dev libvorbis-dev libopenal-dev \
		gettext libpq-dev postgresql-server-dev-all libleveldb-dev \
		libcurl4-openssl-dev)
	# for better coverage, build some jobs with luajit
	if [ -n "$WITH_LUAJIT" ]; then
		pkgs+=(libluajit-5.1-dev)
	fi

	sudo apt-get update
	sudo apt-get install -y --no-install-recommends ${pkgs[@]}
}

# Mac OSX build only
install_macosx_deps() {
	brew update
	brew install freetype gettext hiredis irrlicht leveldb libogg libvorbis luajit
	if brew ls | grep -q jpeg; then
		brew upgrade jpeg
	else
		brew install jpeg
	fi
	#brew upgrade postgresql
}
