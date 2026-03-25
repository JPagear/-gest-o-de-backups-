# -gest-o-de-backups-
Versão original (trabalho académico)
Script interativo de gestão de backups de websites em /var/www. Permite listar ficheiros e backups, criar backups comprimidos com retenção automática dos 5 mais recentes, restaurar e apagar backups individualmente, e enviar relatório por email via msmtp. Desenvolvido como trabalho académico para a unidade curricular de Sistemas Operativos.

Versão apriorada — Melhorias funcionais para sites estáticos reais
Adiciona exclusão automática de ficheiros irrelevantes para sites estáticos (.git, node_modules, .env, cache, logs, lixo de SO), verificação de espaço em disco antes de criar backups, verificação de integridade do backup após criação, log persistente em /var/log/backup_websites.log com opção de consulta no menu, e tamanho dos ficheiros visível na listagem de backups.
