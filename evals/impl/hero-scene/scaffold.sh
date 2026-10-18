set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
rm -r src/scene/scenes/home/HomeScene.ts src/shaders
