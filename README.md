# Zero Graphics

A very minimal OpenGL ES 2.0 library for Zig. Opens you a window and let's you draw things.
Comes with a pixel-perfect 2D renderer and maybe some day even with a bit of a 3D api.

## Project status
Very *work in progress*. Right now it's more a proof of concept than everything else

## Project Goals

### Basic Framework
- [ ] Support the following platforms
  - [x] Wasm
  - [x] Linux Desktop
  - [ ] Windows Desktop (not tested, but should work via SDL2)
  - [x] Android
- [x] Create an OpenGL ES 2.0 context
- [ ] Provide input events
  - [ ] Single pointer motion (finger or mouse)
  - [ ] Single click event (finger, mouse)
  - [ ] Text input for keyboard (utf-8 encoded)
- [ ] Provide window events
  - [ ] Resize
  - [ ] Close
- [ ] Provide access to the underlying backend
- [ ] Allow creation of single-file applications
  - [ ] Single executable for easy distribution
  - [ ] Embedded resources

### 2D Rendering library
- [ ] Pixel perfect drawing of
  - [x] Lines
  - [x] Rectangles
  - [x] Images
- [ ] TTF font rendering via [`stb_ttf`](https://github.com/nothings/stb)
- [ ] Image loading via [`stb_image`](https://github.com/nothings/stb)

## Features

- Support for desktop linux
- Mobile linux (PinePhone) supported as well
- Browser support via Wasm
- *coming soon:* Android support
- Pixel perfect 2D rendering


## Dependencies

### Desktop
- SDL2

### Web
- [js glue code](www/binding.js)

### Android
- Android SDK
- Android NDK
- Android Build Tools
- OpenJDK
- some other tools

## Building / Running

### Desktop PC

Requires `SDL2` to be installed.

```sh
zig build -Dbackend=desktop_sdl2 run
```

A window should open with the application in fullscreen.

### Web/Wasm version

Includes a teeny tiny web server for debugging.

```sh
zig build -Dbackend=wasm install run
```

Now visit http://127.0.0.1:8000/index.htm to see the demo.

### Android

Connect your phone first and install both a JDK as well as the Android SDK with NDK included.

```sh
zig build -Dbackend=android run
```

The app should now be installed and started on your phone.