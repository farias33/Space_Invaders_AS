#!/usr/bin/env bash
# Roda o Space Invaders no simulador P3 (p3js) direto no terminal.
# Terminal com pelo menos 30 linhas x 80 colunas. Ctrl-C para sair.
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME/p3js" && exec node p3sim.js "$DIR/${1:-space_invaders.as}"
