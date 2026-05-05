.PHONY: project open build clean

project:
	xcodegen generate

open: project
	open YTMBar.xcodeproj

build: project
	xcodebuild -project YTMBar.xcodeproj -scheme YTMBar -configuration Debug build

clean:
	rm -rf YTMBar.xcodeproj
	rm -rf build/
	rm -rf ~/Library/Developer/Xcode/DerivedData/YTMBar-*
