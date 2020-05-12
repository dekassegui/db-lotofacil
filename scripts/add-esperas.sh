#/bin/bash

# executa o script sql que adiciona tabelas, triggers e views
sqlite3 loto.sqlite '.read sql/esperas.sql'
