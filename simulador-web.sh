#!/usr/bin/env bash
# Abre o simulador P3 (p3js) com interface grafica em http://localhost:8000
echo "Abra http://localhost:8000 no navegador (Ctrl-C para parar)"
exec python3 -m http.server 8000 -d "$HOME/p3js/www"
