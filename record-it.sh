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

record ./step-01.sh "Step 01 - Deploy CoreOS"
record ./step-02.sh "Step 02 - Deploy Fleet Units"
record ./step-03.sh "Step 03 - Start Fleet Units"

