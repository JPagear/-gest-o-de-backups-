
# Gestão de Backups de Websites

Script Bash interativo para gestão de backups de websites estáticos em `/var/www`.

Desenvolvido inicialmente como trabalho académico para a unidade curricular de Sistemas Operativos (CTESP — Redes e Sistemas Informáticos, ESTGA 2024/2025), e posteriormente melhorado para uso em ambiente real.

---

## Branches

| Branch | Descrição |
|---|---|
| `main` | Versão melhorada para sites estáticos reais |
| `original` | Versão original entregue como trabalho académico |

---

## Funcionalidades

### Versão original (`branch: original`)
- Listagem de ficheiros por site em `/var/www`
- Listagem de backups com filtro customizado, site a site, ou todos
- Criação de backups comprimidos (`.tar.bz2`) com retenção automática dos 5 mais recentes
- Restauro de backups com seleção por número
- Remoção de backups individuais
- Relatório por email via `msmtp`

### Versão melhorada (`branch: main`)
Mantém todas as funcionalidades da versão original e adiciona:
- Exclusão automática de ficheiros irrelevantes para sites estáticos: `.git`, `node_modules`, `.env`, cache, logs, lixo de SO (`.DS_Store`, `Thumbs.db`)
- Verificação de espaço em disco antes de criar cada backup
- Verificação de integridade do backup após criação (`tar -tjf`)
- Log persistente em `/var/log/backup_websites.log`
- Visualização do log diretamente no menu (opção 6)
- Tamanho de cada ficheiro visível na listagem de backups

---

## Requisitos

- Linux com Bash 4+
- `tar`, `find`, `df`, `du` (incluídos na maioria das distribuições)
- `msmtp` configurado (apenas para envio de relatório por email)
- Executar como `root` (`sudo`)

---

## Instalação e uso

```bash
# Clona o repositório
git clone https://github.com/JPagear/-gest-o-de-backups-.git
cd -gest-o-de-backups-

# Dá permissão de execução
chmod +x versao-apriorada.sh

# Executa como superutilizador
sudo ./versao-apriorada.sh
```

---

## Configuração

No topo do script estão as variáveis de configuração. Edita conforme necessário sem tocar no resto do código:

```bash
DIR_SITES="/var/www"          # Diretório onde estão os sites
DIR_BACKUPS="/backups"        # Diretório onde ficam os backups
BACKUPS_A_MANTER=5            # Número de backups a manter por site
ESPACO_MINIMO_MB=100          # Espaço mínimo livre antes de criar backup
LOG_FILE="/var/log/backup_websites.log"
```

Para adicionar ou remover exclusões do backup, edita o array `EXCLUSOES`:

```bash
EXCLUSOES=(
    ".git"
    "node_modules"
    ".env"
    # adiciona aqui outros padrões
)
```

---

## Estrutura dos backups

Os ficheiros de backup seguem o formato:

```
/backups/nome-do-site-YYYY-MM-DD_HH-MM-SS.tar.bz2
```

Exemplo:
```
/backups/portfolio-2025-03-25_14-30-00.tar.bz2
```

---

## Diferenças técnicas entre versões

| | Original | Melhorada |
|---|---|---|
| Exclusão de `.git` e `node_modules` | Não | Sim |
| Verificação de espaço em disco | Não | Sim |
| Verificação de integridade do backup | Não | Sim |
| Log persistente | Não | Sim |
| Proteção contra `rm -rf` com variável vazia | Não | Sim |
| Validação de input numérico | Não | Sim |
| Ordenação de backups por data fiável | Não | Sim |
