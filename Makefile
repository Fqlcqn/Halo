.PHONY: project build release test verify preview status snapshot install package
project:
	python3 Scripts/project.py
build: project
	xcodebuild -quiet -project Halo.xcodeproj -scheme Halo -configuration Debug -derivedDataPath Build/HaloDerivedData build
release: project
	xcodebuild -quiet -project Halo.xcodeproj -scheme Halo -configuration Release -derivedDataPath Build/HaloDerivedData build
	python3 Scripts/release.py record-build
test:
	python3 Scripts/test.py
verify: test build
	"Build/Debug/Halo.app/Contents/MacOS/Halo" --self-test
preview: build
	open "Build/Debug/Halo.app" --args --safe-mode
status:
	python3 Scripts/release.py check
	python3 Scripts/deploy.py status
snapshot:
	python3 Scripts/release.py snapshot
install: release
	python3 Scripts/deploy.py install
package: release
	python3 Scripts/package.py
