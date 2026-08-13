function dockerps() {
  dps "$@"
}
function dps() {
  docker ps "$@" --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
}
