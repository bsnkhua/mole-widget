# Swift Testing in Command Line Tools (without full Xcode) ships as a separate
# framework; the SwiftPM test runner needs a global -F flag, otherwise
# canImport(Testing) == false and tests silently do not run.
FRAMEWORKS = /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TESTFLAGS = -Xswiftc -F -Xswiftc $(FRAMEWORKS)

APP_NAME = Mole Widget
DIST = dist/$(APP_NAME).app

.PHONY: run test app clean

run:
	swift run MoleWidget

# make test            — run all tests
# make test FILTER=Fmt — run only suites/tests matching FILTER
test:
	swift test $(TESTFLAGS) $(if $(FILTER),--filter $(FILTER))

app:
	swift build -c release
	rm -rf "$(DIST)"
	mkdir -p "$(DIST)/Contents/MacOS"
	cp .build/release/MoleWidget "$(DIST)/Contents/MacOS/MoleWidget"
	cp Resources/Info.plist "$(DIST)/Contents/Info.plist"
	mkdir -p "$(DIST)/Contents/Resources"
	cp Resources/AppIcon.icns "$(DIST)/Contents/Resources/AppIcon.icns"
	mkdir -p "$(DIST)/Contents/Frameworks"
	cp -R .build/release/Sparkle.framework "$(DIST)/Contents/Frameworks/Sparkle.framework"
	install_name_tool -add_rpath "@executable_path/../Frameworks" "$(DIST)/Contents/MacOS/MoleWidget"
	codesign --force --sign - "$(DIST)/Contents/Frameworks/Sparkle.framework"
	codesign --force --sign - "$(DIST)"
	@echo "Done: $(DIST)"

clean:
	rm -rf .build dist
