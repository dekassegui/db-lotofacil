#/bin/bash

# executa o script sql que implementa o esquema "param"
sqlite3 loto.sqlite '.read sql/param.sql'
