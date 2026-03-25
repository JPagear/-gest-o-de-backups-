#!/bin/bash
# ==============================================================================
# backup_websites.sh
# Gestão de backups de websites estáticos em /var/www
#
# Funcionalidades:
#   - Backup de ficheiros de sites estáticos (HTML/CSS/JS/assets)
#   - Exclusão automática de lixo: .git, node_modules, .env, cache, logs, lixo de SO
#   - Verificação de integridade do backup após criação
#   - Verificação de espaço em disco antes de criar backup
#   - Retenção automática (mantém os N backups mais recentes por site)
#   - Log persistente em /var/log/backup_websites.log
#   - Relatório por email via msmtp (opcional)
#
# Uso: sudo ./backup_websites.sh
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# CONFIGURAÇÃO — edita aqui sem tocar no resto do script
# ------------------------------------------------------------------------------
DIR_SITES="/var/www"
DIR_BACKUPS="/backups"
BACKUPS_A_MANTER=5
ESPACO_MINIMO_MB=100          # Espaço mínimo livre em /backups antes de criar backup
LOG_FILE="/var/log/backup_websites.log"
MAIL_REMETENTE="trabalhosistemasoperativos@gmail.com"
MAIL_RELATORIO="/tmp/email_backup.txt"

# Padrões de exclusão para sites estáticos.
# Estes padrões são passados ao tar com --exclude.
# Adiciona ou remove entradas conforme necessário.
EXCLUSOES=(
    ".git"           # Histórico de desenvolvimento — não é conteúdo do site
    ".gitignore"     # Ficheiro de configuração de desenvolvimento
    "node_modules"   # Dependências reconstruíveis — podem pesar centenas de MB
    ".env"           # Credenciais e variáveis de ambiente — nunca devem ir para backups
    ".env.*"         # Variantes: .env.local, .env.production, etc.
    ".DS_Store"      # Lixo do macOS
    "Thumbs.db"      # Lixo do Windows Explorer
    "desktop.ini"    # Lixo do Windows
    "*.log"          # Logs locais do projeto
    ".cache"         # Diretórios de cache
    "*.cache"        # Ficheiros de cache
    ".sass-cache"    # Cache do compilador Sass
    "dist"           # Build artifacts — reconstruíveis a partir do source
    ".tmp"           # Ficheiros temporários
    "tmp"            # Diretório temporário
)

menu_estado=1

# ------------------------------------------------------------------------------
# FUNÇÕES DE LOG E UTILITÁRIOS
# ------------------------------------------------------------------------------

# Escreve uma linha no log com timestamp.
# Uso: log "mensagem"
log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Valida se o input é um número inteiro positivo.
validar_numero() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Devolve os argumentos --exclude para o tar com base no array EXCLUSOES.
# Uso: tar ... $(construir_exclusoes) ...
construir_exclusoes() {
    local args=()
    for padrao in "${EXCLUSOES[@]}"; do
        args+=(--exclude="$padrao")
    done
    echo "${args[@]}"
}

# Verifica se há espaço suficiente em disco antes de criar um backup.
# Compara o tamanho do site com o espaço livre em DIR_BACKUPS.
# Uso: verificar_espaco "$diretorio_do_site"
verificar_espaco() {
    local diretorio="$1"
    local tamanho_site_kb espaco_livre_kb espaco_minimo_kb

    tamanho_site_kb=$(du -sk "$diretorio" 2>/dev/null | cut -f1)
    espaco_livre_kb=$(df -k "$DIR_BACKUPS" | awk 'NR==2 {print $4}')
    espaco_minimo_kb=$((ESPACO_MINIMO_MB * 1024))

    # Verifica espaço mínimo configurado
    if [ "$espaco_livre_kb" -lt "$espaco_minimo_kb" ]; then
        echo -e ">>[ERRO]<<\nEspaço em disco insuficiente em $DIR_BACKUPS."
        echo -e "Livre: $((espaco_livre_kb / 1024)) MB | Mínimo exigido: ${ESPACO_MINIMO_MB} MB"
        log "ERRO: Espaço insuficiente para backup de $(basename "$diretorio"). Livre: $((espaco_livre_kb / 1024)) MB"
        return 1
    fi

    # Avisa se o site é maior do que metade do espaço livre (possível problema)
    if [ "$tamanho_site_kb" -gt "$((espaco_livre_kb / 2))" ]; then
        echo -e ">>[AVISO]<<\nO site ocupa $((tamanho_site_kb / 1024)) MB e só há $((espaco_livre_kb / 1024)) MB livres."
        echo -e "O backup pode falhar a meio. Continuar mesmo assim?"
        echo -e "1) Sim.\n2) Não, cancelar este backup."
        read -rp "->" input_utilizador
        [ "$input_utilizador" = "1" ] || return 1
    fi

    return 0
}

# Verifica a integridade de um ficheiro tar.bz2 após criação.
# Uso: verificar_integridade "$ficheiro_backup"
verificar_integridade() {
    local ficheiro="$1"
    if tar -tjf "$ficheiro" > /dev/null 2>&1; then
        return 0
    else
        echo -e ">>[ERRO]<<\nO backup está corrompido: $ficheiro"
        log "ERRO: Backup corrompido após criação: $ficheiro"
        rm -f "$ficheiro"
        return 1
    fi
}

# Formata o tamanho de um ficheiro de forma legível (KB, MB, GB).
formatar_tamanho() {
    local ficheiro="$1"
    du -sh "$ficheiro" 2>/dev/null | cut -f1
}

# Lista backups de um site ordenados do mais recente para o mais antigo.
listar_backups_site() {
    local site="$1"
    find "$DIR_BACKUPS" -type f -name "${site}-*.tar.bz2" | sort -r
}

# Filtra backups por nome de site sem apanhar prefixos.
# Ex: "loja" não apanha "loja-antiga"
filtro_site() {
    echo "/${1}-[0-9]"
}

# Formata mensagens de contagem
FormatarContagemDiretorios() {
    local q=$1
    if   [ "$q" -eq 0 ]; then echo "Não foram encontrados diretórios! ($q diretórios)"
    elif [ "$q" -eq 1 ]; then echo "Foi encontrado: $q diretório."
    else                       echo "Foram encontrados: $q diretórios."
    fi
}

FormatarContagemFicheiros() {
    local q=$1
    if   [ "$q" -eq 0 ]; then echo "Não foram encontrados ficheiros! ($q ficheiros)"
    elif [ "$q" -eq 1 ]; then echo "Foi encontrado: $q ficheiro."
    else                       echo "Foram encontrados: $q ficheiros."
    fi
}

FormatarContagemBackupsAntigos() {
    local q=$1
    if   [ "$q" -eq 0 ]; then echo "Não foram encontrados backups antigos. ($q)"
    elif [ "$q" -eq 1 ]; then echo "Foi encontrado e apagado $q backup antigo."
    else                       echo "Foram encontrados e apagados $q backups antigos."
    fi
}

FormatarContagemBackups() {
    local q=$1
    if   [ "$q" -eq 0 ]; then echo "Não foram encontrados backups! ($q backups)"
    elif [ "$q" -eq 1 ]; then echo "Foi encontrado $q backup."
    else                       echo "Foram encontrados $q backups."
    fi
}


# ------------------------------------------------------------------------------
# LISTAR FICHEIROS
# ------------------------------------------------------------------------------
Listar_ficheiros() {
    local diretorios_totais texto diretorio numficheiros ficheiros input_utilizador

    diretorios_totais=$(find "$DIR_SITES" -mindepth 1 -maxdepth 1 -type d | wc -l)
    texto=$(FormatarContagemDiretorios "$diretorios_totais")

    echo -e "\n\n\n\nLISTAGEM DOS DIRETÓRIOS DE SITES\n---------------------------------\n$texto"

    for diretorio in "$DIR_SITES"/*/; do
        [ -d "$diretorio" ] || continue

        echo -e "\n\nGostaria de visualizar o conteúdo do diretório: $(basename "$diretorio")?"
        echo -e "1) Sim.\n2) Não e continuar para o próximo.\n3) Voltar para o menu."
        read -rp "->" input_utilizador

        case $input_utilizador in
            1)
                numficheiros=$(find "$diretorio" -type f | wc -l)
                ficheiros=$(find "$diretorio" -type f)
                texto=$(FormatarContagemFicheiros "$numficheiros")

                echo -e "\n\n----------------------------------------------"
                echo -e "Dentro do diretório: $diretorio\n> $texto"
                echo -e "\n> Ficheiros listados:\n-------------------"
                echo -e "$ficheiros\n"
                read -rp "Concluído! Pressione ENTER para continuar para o próximo site."
                ;;
            2)
                read -rp "A saltar. Pressione ENTER para continuar."
                ;;
            3) break ;;
            *)
                echo -e ">>[ERRO]<<\nOpção inválida. A saltar para o próximo site..."
                read -rp "Pressione ENTER para continuar..."
                ;;
        esac
    done

    echo -e "\n\n----------\nTerminadas as operações de leitura de ficheiros!"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# LISTAR BACKUPS
# ------------------------------------------------------------------------------
Listar_backups() {
    local backups_guardados texto input_utilizador filtro backups_encontrados num_encontrados

    echo -e "\n\n\n\nLISTAGEM DOS BACKUPS\n--------------------\n"

    if [ ! -d "$DIR_BACKUPS" ]; then
        echo -e ">>[ERRO]<<\nNão existe o diretório $DIR_BACKUPS."
        read -rp "Pressione ENTER para continuar para o menu..."
        return
    fi

    backups_guardados=$(find "$DIR_BACKUPS" -type f -name "*.tar.bz2" | wc -l)
    texto=$(FormatarContagemBackups "$backups_guardados")

    echo -e ">>[SUCESSO!]<<\nFoi encontrado o diretório $DIR_BACKUPS."
    read -rp "Pressione ENTER para continuar..."

    echo -e "\n\n----------------------------------------------------------\n$texto"
    echo -e "Como gostaria de visualizar os backups?"
    echo -e "1) Filtro customizado.\n2) Site a site.\n3) Ver todos.\n4) Voltar para o menu."
    read -rp "->" input_utilizador

    case $input_utilizador in
        1)
            echo -e "\nFILTRO CUSTOMIZADO\nExemplo: 'site1' mostra backups cujo nome contém 'site1'.\n"
            read -rp "-> Insira um filtro: " filtro

            backups_encontrados=$(find "$DIR_BACKUPS" -type f | grep "$(filtro_site "$filtro")" | sort -r || true)
            num_encontrados=$(echo "$backups_encontrados" | grep -c . || true)
            texto=$(FormatarContagemBackups "$num_encontrados")

            echo -e "\n----------------------------------------------\nDentro de $DIR_BACKUPS\n> $texto"
            echo -e "\n> Backups encontrados:\n----------------------"
            # Mostra cada backup com tamanho
            while IFS= read -r b; do
                [ -n "$b" ] && echo "  $(formatar_tamanho "$b")  $b"
            done <<< "$backups_encontrados"
            ;;
        2)
            echo -e "\nSITE A SITE\n"
            read -rp "Pressione ENTER para continuar..."

            for diretorio in "$DIR_SITES"/*/; do
                [ -d "$diretorio" ] || continue
                local nome_do_site
                nome_do_site=$(basename "$diretorio")
                mapfile -t bs < <(listar_backups_site "$nome_do_site")
                texto=$(FormatarContagemBackups "${#bs[@]}")

                echo -e "\n----------------------------------------------"
                echo -e "Site: $nome_do_site\n> $texto"
                for b in "${bs[@]}"; do
                    echo "  $(formatar_tamanho "$b")  $b"
                done
                read -rp "Pressione ENTER para continuar para o próximo site..."
            done
            ;;
        3)
            echo -e "\nTODOS OS BACKUPS (ordem decrescente de data)\n"
            read -rp "Pressione ENTER para continuar..."

            num_encontrados=$(find "$DIR_BACKUPS" -type f -name "*.tar.bz2" | wc -l)
            texto=$(FormatarContagemBackups "$num_encontrados")
            echo -e "\n----------------------------------------------\nDentro de $DIR_BACKUPS\n> $texto\n"

            while IFS= read -r b; do
                [ -n "$b" ] && echo "  $(formatar_tamanho "$b")  $b"
            done < <(find "$DIR_BACKUPS" -type f -name "*.tar.bz2" | sort -r)
            read -rp "Pressione ENTER para continuar..."
            ;;
        4) ;;
        *)
            echo -e ">>[ERRO]<<\nOpção inválida."
            read -rp "Pressione ENTER para continuar..."
            ;;
    esac

    echo -e "\n\n----------\nTerminadas as operações de leitura de backups!"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# CRIAR BACKUPS
# ------------------------------------------------------------------------------
Criar_backups() {
    local data texto_para_mail nome_do_site num_backups_antigos input_utilizador ficheiro_backup

    echo -e "\n\n\n\nCRIAÇÃO DE BACKUPS\n------------------"
    echo -e "Ficheiros excluídos automaticamente: .git, node_modules, .env, cache, logs, lixo de SO\n"

    if [ ! -d "$DIR_BACKUPS" ]; then
        echo -e ">>[AVISO]<<\nNão existe $DIR_BACKUPS. A criar..."
        mkdir -p "$DIR_BACKUPS"
        log "INFO: Diretório $DIR_BACKUPS criado."
    else
        echo -e ">>[SUCESSO!]<<\nFoi encontrado o diretório $DIR_BACKUPS."
    fi
    read -rp "Pressione ENTER para continuar..."

    data=$(date +%Y-%m-%d_%H-%M-%S)
    texto_para_mail="RELATÓRIO DE BACKUP DE WEBSITES\n--------------------------------\n\n"
    texto_para_mail+="Data e hora: $data\n\nDETALHES DOS BACKUPS:\n--------------------\n\n"

    for diretorio in "$DIR_SITES"/*/; do
        [ -d "$diretorio" ] || continue
        nome_do_site=$(basename "$diretorio")
        ficheiro_backup="$DIR_BACKUPS/${nome_do_site}-${data}.tar.bz2"

        echo -e "\n\n\nGostaria de fazer backup do site: $nome_do_site?"
        echo -e "1) Sim.\n2) Não e continuar para o próximo.\n3) Voltar para o menu."
        read -rp "->" input_utilizador

        case $input_utilizador in
            1)
                # Verifica espaço disponível antes de começar
                verificar_espaco "$diretorio" || {
                    texto_para_mail+="FALHOU (sem espaço): $nome_do_site\n\n"
                    continue
                }

                echo -e "\nA criar backup de $nome_do_site (a excluir lixo)..."
                log "INFO: A iniciar backup de $nome_do_site"

                # Cria o backup com todas as exclusões configuradas
                # shellcheck disable=SC2046
                tar -cjf "$ficheiro_backup" \
                    $(construir_exclusoes) \
                    -C "$DIR_SITES" "$nome_do_site" 2>/dev/null

                # Verifica integridade antes de confirmar sucesso
                echo -e "A verificar integridade do backup..."
                if ! verificar_integridade "$ficheiro_backup"; then
                    texto_para_mail+="FALHOU (backup corrompido): $nome_do_site\n\n"
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                local tamanho
                tamanho=$(formatar_tamanho "$ficheiro_backup")

                echo -e "\n-----------------------------------------------------"
                echo -e ">>[SUCESSO]<<\nBackup criado: $(basename "$ficheiro_backup") ($tamanho)"
                log "INFO: Backup criado com sucesso: $ficheiro_backup ($tamanho)"

                # Limpeza de backups antigos
                echo -e "A limpar backups antigos de $nome_do_site (mantém os $BACKUPS_A_MANTER mais recentes)..."
                num_backups_antigos=$(listar_backups_site "$nome_do_site" | tail -n +"$((BACKUPS_A_MANTER + 1))" | wc -l)
                local texto_antigos
                texto_antigos=$(FormatarContagemBackupsAntigos "$num_backups_antigos")
                echo -e "$texto_antigos"

                local removidos=""
                while IFS= read -r backup; do
                    [ -n "$backup" ] || continue
                    echo "  A remover: $backup"
                    removidos+="$backup\n"
                    rm -f "$backup"
                    log "INFO: Backup antigo removido: $backup"
                done < <(listar_backups_site "$nome_do_site" | tail -n +"$((BACKUPS_A_MANTER + 1))")

                texto_para_mail+="Site: $nome_do_site\n"
                texto_para_mail+="Ficheiro: $(basename "$ficheiro_backup") ($tamanho)\n"
                texto_para_mail+="Backups antigos removidos: $num_backups_antigos\n"
                texto_para_mail+="Removidos:\n${removidos}\n"

                read -rp "Pressione ENTER para continuar..."
                ;;
            2)
                echo -e "Backup ignorado para: $nome_do_site"
                read -rp "Pressione ENTER para continuar..."
                ;;
            3) break ;;
            *)
                echo -e ">>[ERRO]<<\nOpção inválida. A saltar para o próximo site..."
                read -rp "Pressione ENTER para continuar..."
                ;;
        esac
    done

    echo -e "\n\nGostaria de enviar um email com o relatório?\n1) Sim\n2) Não"
    read -rp "->" input_utilizador

    case $input_utilizador in
        1)
            local mail_destinatario
            read -rp "Insira o destinatário: " mail_destinatario
            echo -e "$texto_para_mail" > "$MAIL_RELATORIO"
            {
                echo "Subject: Relatório de Backups - $data"
                echo "To: $mail_destinatario"
                echo "From: $MAIL_REMETENTE"
                echo ""
                cat "$MAIL_RELATORIO"
            } | msmtp "$mail_destinatario"
            echo -e "Email enviado para $mail_destinatario"
            log "INFO: Relatório de backup enviado para $mail_destinatario"
            ;;
        2) echo -e "Não será enviado email." ;;
    esac

    echo -e "\n\n----------\nTerminadas todas as operações de backups!"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# RESTAURAR BACKUPS
# ------------------------------------------------------------------------------
Restaurar_backups() {
    local backups_guardados texto nome_do_site num_backups_site backups_site input_utilizador backup_selecionado

    echo -e "\n\n\n\nRESTAURAÇÃO DE BACKUPS\n----------------------"

    if [ ! -d "$DIR_BACKUPS" ]; then
        echo -e ">>[ERRO]<<\nNão existe o diretório $DIR_BACKUPS."
        read -rp "Pressione ENTER para continuar para o menu..."
        return
    fi

    echo -e ">>[SUCESSO!]<<\nFoi encontrado o diretório $DIR_BACKUPS."
    read -rp "Pressione ENTER para continuar..."

    backups_guardados=$(find "$DIR_BACKUPS" -type f -name "*.tar.bz2" | wc -l)
    texto=$(FormatarContagemBackups "$backups_guardados")
    echo -e "\n\n----------------------------------------------------------\n$texto\nA percorrer $DIR_BACKUPS site a site."
    read -rp "Pressione ENTER para continuar..."

    for diretorio in "$DIR_SITES"/*/; do
        [ -d "$diretorio" ] || continue
        nome_do_site=$(basename "$diretorio")

        mapfile -t backups_site < <(listar_backups_site "$nome_do_site")
        num_backups_site=${#backups_site[@]}
        texto=$(FormatarContagemBackups "$num_backups_site")

        echo -e "\n\n---------------------------------------------"
        echo -e "Site    -> $nome_do_site\n$texto"
        echo -e "Gostaria de restaurar um backup deste site?"
        echo -e "1) Sim.\n2) Não e continuar para o próximo.\n3) Voltar para o menu."
        read -rp "->" input_utilizador

        case $input_utilizador in
            1)
                if [ "$num_backups_site" -eq 0 ]; then
                    echo -e "Não foram encontrados backups para este site. A saltar..."
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                echo -e "\n---------------------------------------------\nSite -> $nome_do_site\nBackups disponíveis:"
                local i
                for i in "${!backups_site[@]}"; do
                    local tam
                    tam=$(formatar_tamanho "${backups_site[$i]}")
                    echo "  $((i + 1))) [$tam]  ${backups_site[$i]}"
                done
                echo "---------------------------"

                read -rp "Insira o número do backup que quer restaurar: " input_utilizador

                if ! validar_numero "$input_utilizador" || \
                   [ "$input_utilizador" -lt 1 ] || \
                   [ "$input_utilizador" -gt "$num_backups_site" ]; then
                    echo -e ">>[ERRO]<<\nOpção inválida. A saltar para o próximo site..."
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                backup_selecionado="${backups_site[$((input_utilizador - 1))]}"

                if [ -z "$nome_do_site" ] || [ -z "$backup_selecionado" ]; then
                    echo -e ">>[ERRO CRÍTICO]<<\nVariável vazia. Operação cancelada por segurança."
                    log "ERRO: Variável vazia na restauração. site='$nome_do_site' backup='$backup_selecionado'"
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                echo -e "\nA restaurar: $backup_selecionado"
                log "INFO: A restaurar backup de $nome_do_site: $backup_selecionado"

                rm -rf "${DIR_SITES:?}/${nome_do_site:?}"
                tar -xjf "$backup_selecionado" -C "$DIR_SITES"

                echo -e ">>[SUCESSO]<<\nBackup restaurado com sucesso!"
                log "INFO: Backup restaurado com sucesso: $nome_do_site"
                read -rp "Pressione ENTER para continuar..."
                ;;
            2)
                read -rp "A saltar. Pressione ENTER para continuar."
                ;;
            3) break ;;
            *)
                echo -e ">>[ERRO]<<\nOpção inválida. A saltar..."
                read -rp "Pressione ENTER para continuar..."
                ;;
        esac
    done

    echo -e "\n\n----------\nTerminadas todas as operações de restaurar backups!"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# APAGAR BACKUPS
# ------------------------------------------------------------------------------
Apagar_Backups() {
    local backups_guardados texto nome_do_site num_backups_site backups_site input_utilizador backup_selecionado

    echo -e "\n\n\n\nAPAGAR BACKUPS\n--------------"

    if [ ! -d "$DIR_BACKUPS" ]; then
        echo -e ">>[ERRO]<<\nNão existe o diretório $DIR_BACKUPS."
        read -rp "Pressione ENTER para continuar para o menu..."
        return
    fi

    echo -e ">>[SUCESSO!]<<\nFoi encontrado o diretório $DIR_BACKUPS."
    read -rp "Pressione ENTER para continuar..."

    backups_guardados=$(find "$DIR_BACKUPS" -type f -name "*.tar.bz2" | wc -l)
    texto=$(FormatarContagemBackups "$backups_guardados")
    echo -e "\n\n----------------------------------------------------------\n$texto\nA percorrer $DIR_BACKUPS site a site."

    for diretorio in "$DIR_SITES"/*/; do
        [ -d "$diretorio" ] || continue
        nome_do_site=$(basename "$diretorio")

        mapfile -t backups_site < <(listar_backups_site "$nome_do_site")
        num_backups_site=${#backups_site[@]}
        texto=$(FormatarContagemBackups "$num_backups_site")

        echo -e "\n\n---------------------------------------------"
        echo -e "Site    -> $nome_do_site\n$texto"
        echo -e "Gostaria de apagar um backup deste site?"
        echo -e "1) Sim.\n2) Não e continuar para o próximo.\n3) Voltar para o menu."
        read -rp "->" input_utilizador

        case $input_utilizador in
            1)
                if [ "$num_backups_site" -eq 0 ]; then
                    echo -e "Não foram encontrados backups para este site. A saltar..."
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                echo -e "\n---------------------------------------------\nSite -> $nome_do_site\nBackups disponíveis:"
                local i
                for i in "${!backups_site[@]}"; do
                    local tam
                    tam=$(formatar_tamanho "${backups_site[$i]}")
                    echo "  $((i + 1))) [$tam]  ${backups_site[$i]}"
                done
                echo "---------------------------"

                read -rp "Insira o número do backup que quer apagar: " input_utilizador

                if ! validar_numero "$input_utilizador" || \
                   [ "$input_utilizador" -lt 1 ] || \
                   [ "$input_utilizador" -gt "$num_backups_site" ]; then
                    echo -e ">>[ERRO]<<\nOpção inválida. A saltar..."
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                backup_selecionado="${backups_site[$((input_utilizador - 1))]}"

                if [ -z "$backup_selecionado" ]; then
                    echo -e ">>[ERRO CRÍTICO]<<\nVariável de backup vazia. Operação cancelada."
                    log "ERRO: Variável vazia na operação de apagar. backup='$backup_selecionado'"
                    read -rp "Pressione ENTER para continuar..."
                    continue
                fi

                rm -f "$backup_selecionado"
                echo -e ">>[SUCESSO]<<\nBackup apagado com sucesso!"
                log "INFO: Backup apagado manualmente: $backup_selecionado"
                read -rp "Pressione ENTER para continuar..."
                ;;
            2)
                read -rp "A saltar. Pressione ENTER para continuar."
                ;;
            3) break ;;
            *)
                echo -e ">>[ERRO]<<\nOpção inválida. A saltar..."
                read -rp "Pressione ENTER para continuar..."
                ;;
        esac
    done

    echo -e "\n\n----------\nTerminadas todas as operações de apagar backups!"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# VER LOG
# ------------------------------------------------------------------------------
Ver_log() {
    echo -e "\n\n\n\nLOG DE OPERAÇÕES\n----------------"

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "Ainda não existe log em $LOG_FILE."
        read -rp "Pressione ENTER para voltar para o menu..."
        return
    fi

    echo -e "Últimas 50 entradas de $LOG_FILE:\n"
    tail -n 50 "$LOG_FILE"
    echo -e "\n------------------"
    echo -e "Log completo em: $LOG_FILE"
    read -rp "Pressione ENTER para voltar para o menu..."
}


# ------------------------------------------------------------------------------
# SAIR
# ------------------------------------------------------------------------------
Sair_do_programa() {
    menu_estado=0
    log "INFO: Programa terminado pelo utilizador."
    echo -e "\n\n\n\nSAIU DO PROGRAMA"
}


# ------------------------------------------------------------------------------
# MENU PRINCIPAL
# ------------------------------------------------------------------------------
menu_principal() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n>>[ERRO]<<\nEste script deve ser executado como superutilizador.\nPor favor corra: sudo ./backup_websites.sh"
        read -rp "Pressione ENTER para sair..."
        exit 1
    fi

    # Garante que o ficheiro de log existe e tem permissões corretas
    touch "$LOG_FILE" 2>/dev/null || true
    log "INFO: Programa iniciado."

    while [ "$menu_estado" -eq 1 ]; do
        echo -e "\n\n\n\n\nBem-vindo ao programa de Backups de Websites!"
        echo -e "---------------------------------------------"
        echo -e "1. Listar Ficheiros dos Sites"
        echo -e "2. Listar Backups Existentes"
        echo -e "3. Criar Backup"
        echo -e "4. Restaurar Backup"
        echo -e "5. Apagar Backup"
        echo -e "6. Ver Log de Operações"
        echo -e "7. Sair"
        read -rp "->" menu_input

        case $menu_input in
            1) Listar_ficheiros ;;
            2) Listar_backups ;;
            3) Criar_backups ;;
            4) Restaurar_backups ;;
            5) Apagar_Backups ;;
            6) Ver_log ;;
            7) Sair_do_programa ;;
            *)
                echo -e "\n>>[ERRO]<<\nOpção inválida."
                read -rp "Pressione ENTER para continuar..."
                ;;
        esac
    done
}

menu_principal
