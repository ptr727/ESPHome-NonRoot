# ESPHome-NonRoot

[ESPHome](https://esphome.io) Docker container that supports non-root operation.

## License

Licensed under the [MIT License](https://github.com/ptr727/ESPHome-NonRoot/blob/main/LICENSE).

![GitHub License](https://img.shields.io/github/license/ptr727/ESPHome-NonRoot)

## Project

Code and pipeline are on [GitHub](https://github.com/ptr727/ESPHome-NonRoot). Docker images are published on [Docker Hub](https://hub.docker.com/r/ptr727/esphome-nonroot) and rebuilt on each upstream ESPHome release and weekly.

## Docker Tags

- `latest`: Latest `main` branch build.
- `develop`: Latest `develop` branch build.
- `<version>`: Specific ESPHome version (e.g. `2026.6.2`).

## Platform Support

- `linux/amd64`
- `linux/arm64`

## Usage

Refer to the [GitHub README](https://github.com/ptr727/ESPHome-NonRoot/tree/main?tab=readme-ov-file#usage) for configuration, environment variables, and Compose examples. The bundled tool versions (Python, ESPHome, PlatformIO) for a given image can be inspected with `docker run --rm ptr727/esphome-nonroot:latest esphome version`.
