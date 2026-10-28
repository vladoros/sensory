.PHONY: help run build release test package icons fonts settings clean

help:
	@echo "make run                      build, start the simulator, load the face"
	@echo "make build                    build the face into build/"
	@echo "make release                  optimized builds to copy onto a watch"
	@echo "make test                     run the unit tests in the simulator"
	@echo "make package                  optimized release .iq for the Connect IQ store"
	@echo "make icons                    regenerate the launcher icons"
	@echo "make fonts                    regenerate the Inter and Roboto bitmap fonts"
	@echo "make settings                 regenerate the settings XML"
	@echo "make clean                    delete build/"

run:
	tools/run.sh

build:
	tools/build.sh

release:
	RELEASE=1 tools/build.sh

test:
	tools/test.sh

package:
	tools/package.sh

icons:
	uv run tools/gen_icons.py

fonts:
	uv run tools/gen_fonts.py

settings:
	uv run tools/gen_settings.py

clean:
	rm -rf build
