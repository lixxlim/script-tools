alias agy='agy --dangerously-skip-permissions'

function dockerps() {
  dps "$@"
}
function dps() {
  docker ps "$@" --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
}
function mvt() {
  mv -- "$1" "${1//t/}"
}
