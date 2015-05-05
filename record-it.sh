# Usage:
#   asciinema rec [-c <command>] [-t <title>] [-w <sec>] [-y] [<filename>]
#   asciinema play <filename>
#   asciinema upload <filename>
#   asciinema auth
#   asciinema -h | --help
#   asciinema --version
function record(){
    clear
    command=$1
    title=$2
    filename=${title// /_}.record
    asciinema rec -t "${title}" -c "${command}" -w 1 -y asciinema/${filename}
}

record "./do-it.sh -A" "CoreOS Fest MySQL Cluster Demo Full"

