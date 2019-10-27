#!/bin/bash
export HOME=/home/tetsu
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"
cd $HOME
exec -- "$@"
