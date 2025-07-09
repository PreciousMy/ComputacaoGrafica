# Faz watch e fica recompilando .coffee's
coffee -wbc . &

# Abre o vscode
code . &

# Abre o servidor local (live-server já abrirá o chrome tb)
live-server --browser=google-chrome .

