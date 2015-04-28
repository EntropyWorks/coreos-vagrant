# Usage:
#   asciinema rec [-c <command>] [-t <title>] [-w <sec>] [-y] [<filename>]
#   asciinema play <filename>
#   asciinema upload <filename>
#   asciinema auth
#   asciinema -h | --help
#   asciinema --version
clear
asciinema rec -t do-it.sh -c "./do-it.sh -p vmware_fusion" -w 1 -y /tmp/do-it.record
