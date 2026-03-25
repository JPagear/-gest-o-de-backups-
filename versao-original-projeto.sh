#!/bin/bash

# Variáveis de estado para controlar o fluxo do programa
menu_estado=1
menu_input=0

mail_remetente="trabalhosistemasoperativos@gmail.com"
mail_destinatario="trabalhosistemasoperativos@gmail.com"
mail_enviado="/tmp/email_backup.txt"

# Função para formatar a contagem de diretórios encontrados
# Esta função recebe um número como parâmetro e retorna uma mensagem formatada
# de acordo com a quantidade de diretórios encontrados (0, 1 ou mais).
FormatarContagemDiretorios() {
    local quantidade=$1
    if [ "$quantidade" -eq 0 ]; 
        then echo "Não foram encontrados diretórios! ($quantidade diretórios)"
    elif [ "$quantidade" -eq 1 ]; 
        then echo "Foi encontrado: $quantidade diretórios."
    else
        echo "Foram encontrados: $quantidade diretórios."
    fi
}

# Função para formatar a contagem de ficheiros encontrados
# Esta função recebe um número como parâmetro e retorna uma mensagem formatada
# de acordo com a quantidade de ficheiros encontrados (0, 1 ou mais).
FormatarContagemFicheiros() {
    local quantidade=$1
    if [ "$quantidade" -eq 0 ]; 
        then echo "Não foram encontrados ficheiros! ($quantidade ficheiros)"
    elif [ "$quantidade" -eq 1 ]; 
        then echo "Foi encontrado: $quantidade ficheiro."
    else
        echo "Foram encontrados: $quantidade ficheiros."
    fi
}

# Função para formatar a contagem de backups antigos
# Esta função recebe um número como parâmetro e retorna uma mensagem formatada
# de acordo com a quantidade de backups antigos encontrados e apagados (0, 1 ou mais).
FormatarContagemBackupsAntigos() {
    local quantidade=$1
    if [ "$quantidade" -eq 0 ]; then
        echo "Não foram encontrados backups! ($quantidade backups antigos)"
    elif [ "$quantidade" -eq 1 ]; then
        echo "Foi encontrado e apagado $quantidade backup antigos."
    else
        echo "Foram encontrados e apagados $quantidade backups antigos."
    fi
}

# Função para formatar a contagem de backups encontrados
# Esta função recebe um número como parâmetro e retorna uma mensagem formatada
# de acordo com a quantidade de backups encontrados (0, 1 ou mais).
FormatarContagemBackups() {
    local quantidade=$1
    if [ "$quantidade" -eq 0 ]; then
        echo "Não foram encontrados backups! ($quantidade backups)"
    elif [ "$quantidade" -eq 1 ]; then
        echo "Foi encontrado $quantidade backup."
    else
        echo "Foram encontrados $quantidade backups."
    fi
}


#Função usada para listar ficheiros dentro do diretório /var/www.
Listar_ficheiros()
    {  
    # Procura a quantidade de diretórios de sites que existem dentro de /var/www.
    # -wholename serve para filtrar diretórios encontrados dentro de /var/www, sem incluindo
    # o próprio /var/www/, sendo que procura por diretórios dentro dele.
    
    # Depois de encontrar os diretórios, conta-los linha a linha com wc -l.
    # Esses valores são guardados dentro da variável diretorios_totais.

    diretorios_totais=$(find /var/www -type d -wholename "/var/www/*" -maxdepth 1 | wc -l)
    texto=$(FormatarContagemDiretorios "$diretorios_totais")
    #Começa a impressão dos resultados.
    echo -e "\n\n\n\n\
LISTAGEM DOS DIRETÓRIOS DE SITES\n\
---------------------------------\n\
$texto"
        
    # Começa um loop no qual a variável diretório irá assumir o path dos vários diretórios
    # através do /var/www/*/. 
    # /var/www/*/ significa que vai procurar por qualquer coisa depois de /var/www
    # que seja um diretório devido à /.
    # Removendo a barra, iria simplesmente assumir o valor de qualquer ficheiro 
    # ou diretório que encontrar.
    for diretorio in /var/www/*/
    do
    echo -e "\n\n\n\nGostaria de visualizar o conteúdo dentro do diretório do site: $(basename "$diretorio")?"
    echo -e "1) Sim."
    echo -e "2) Não e continuar para o próximo."
    echo -e "3) Voltar para o menu."
    read -p "->" var
    input_utilizador=$var
    case $input_utilizador in
        1) 
            # Conta os ficheiros dentro do diretório por utilizar o valor da variável com o 
            # comando find, procurando por FICHEIROS e mais tarde contando-os com 
            # o comando wc -l, novamente fazendo a sua contagem através das suas linhas.
            
            numficheiros_dentro_diretorio=$(find "$diretorio" -type f | wc -l)
            texto=$(FormatarContagemFicheiros "$numficheiros_dentro_diretorio")


            # Sendo que o valor usado para contar a variável anteriormente
            # já não é necessário, podemos alterar-la para que também sirva
            # para listar os ficheiros utilizando o comando find -type f que procura no caminho
            # do valor da variável anteriormente definida "diretório", que deverá
            # ter o caminho do diretório que está a ser listado.
            ficheiros_dentro_diretorio=$(find "$diretorio" -type f)
            

            # Apresenta o nome do diretório que está a ser procurado E a QUANTIDADE de ficheiros nele.
            echo -e "\
\n\n\n\n----------------------------------------------\n\
Dentro de do diretório: $diretorio\n\
> $texto"
            
            # Apresenta os ficheiros encontrados dentro do diretório do site a ser procurado.
            echo -e "\n\
> Ficheiros listados:\n\
-------------------"
            echo -e "$ficheiros_dentro_diretorio\n"

            read -p "Concluído! Pressione ENTER para continuar para o próximo site.";;
        
        # Esta opção salta a procura para o próximo site.
        2) echo -e "A saltar a listagem para próximo site."
        read -p "Pressione ENTER para continuar para o próximo site.";;
        
        # Esta opção quebra o loop e retorna ao menu.
        3) break ;;

        # Esta opção salta para o próximo site caso seja inserido um comando que não exista.
        *) echo -e "\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar..."

        esac
    done

        # Imprimido após terminarem as operações.
    echo -e "\
\n\n\n\n----------\n\
Terminada as operações de leitura de ficheiros!"

    read -p "Pressione ENTER para voltar para o menu..."
           
}


#---------------------------------------------------------------#
#---------------------------------------------------------------#


# Função para listar os backups existentes no diretório /backups
# Esta função verifica se o diretório /backups existe, se existir
# permite ao utilizador visualizar os backups de diferentes formas.
Listar_backups()
    {   
        

    echo -e "\n\n\n\n\
LISTAGEM DOS BACKUPS\n\
--------------------\n"
# Verifica se o diretório de backups funciona, 
# se não existir, retorna ao menu.
# Por sua vez, se ele existir, continua as operações.
if [ -d /backups ]; 
        then echo -e "\
\n\n\n>>[SUCESSO!]<<\n\
Foi encontrado diretório /backups."
        read -p  "Pressione ENTER para continuar a operação..."
            # Conta o número total de backups existentes no diretório /backups e envia
            # o número de backups_guardados para a função de formatar o texto.
            backups_guardados=$(find /backups -type f -wholename "/backups/*" | wc -l)
            texto=$(FormatarContagemBackups "$backups_guardados")

# Apresenta o menu e a quantidade de BACKUPS totais encontrados.
    echo -e "\n\n\n\
----------------------------------------------------------\n\
$texto"

    echo -e "Como é que gostaria de visualizar o conteúdo dentro do diretório: /backups?"
    echo -e "1) Utilizar um filtro customizado."
    echo -e "2) Procurar site a site."
    echo -e "3) Ver todos os backups."
    echo -e "4) Voltar para o menu."
    read -p "->" var
    input_utilizador=$var
    
    # Aguarda o input do utilizador para escolher uma das opções disponíveis
    case $input_utilizador in


    # Esta opção permite ao utilizador usar um filtro customizado para procurar 
    # por backups.
    1)  echo -e "\
\n\n\n\n-----------------\n\
FILTRO CUSTOMIZADO\n\
O filtro que definir será o que vai ser utilizado na procura de ficheiros backup.\n\
Exemplo: Se escrever site1 serão procurados ficheiros que contém site1 no seu nome.\n"
        
        read -p "-> Insira um filtro:" var
        filtro=$var
        
        # Procura por backups que correspondem ao filtro inserido pelo utilizador
        # e conta quantos backups foram encontrados.
        # Formata ainda o texto para a quantidade de backups encontrados.
        num_backups_encontrados=$(find /backups -type f | grep "/$filtro-" | wc -l)
        backups_encontrados=$(find /backups -type f | grep "/$filtro-" | sort -nr )
        texto=$(FormatarContagemBackups "$num_backups_encontrados")
        

        # Apresenta o número de backups encontrados e depois lista os ficheiros.
        echo -e "\
\n\n\n\n----------------------------------------------\n\
Dentro de do diretório: /backups\n\
> $texto"


        echo -e "\n\
> Backups encontrados:\n\
----------------------"
        echo -e "$backups_encontrados" 
        
        
;;


   # Esta opção permite ao utilizador percorrer os backups todos, sendo estes filtrados
   # através dos nomes dos diretórios encontrados dentro de /var/www.
    2)  echo -e "\
\n\n\n\n-----------------\n\
SITE A SITE \n\
É percorrido filtrado os backups através do nome dos diretórios encontrados dentro de\n\
/var/www.\n\
Exemplo: Se temos /var/www/site1, serão procurados backups com o nome site1.\n"        
        
        read -p "Pressione ENTER para continuar..."
        # Percorre cada diretório em /var/www/ e depois procura por backups correspondentes com o nome 
        # do diretório do site percorrido.
        for diretorio in /var/www/*/
        do
            # Cria o filtro com o nome do diretório a ser percorrido.
            nome_do_site=$(basename "$diretorio")
            filtro=$nome_do_site
            # Procura por backups que correspondem ao nome do site atual, conta a quantidade de backups
            # do site encontrados e formata o texto que apresenta a quantidade de backups.
            num_backups_encontrados=$(find /backups -type f | grep "/$filtro-" | wc -l)
            backups_encontrados=$(find /backups -type f | grep "/$filtro-" |sort -nr )
            texto=$(FormatarContagemBackups "$num_backups_encontrados")

        
        # Apresenta o site a ser procurado E a quantidade de backups encontrados para ele.
        # Seguidamente, são listados os ficheiros de backup encontrados.
        echo -e "\
\n\n\n\n----------------------------------------------\n\
Dentro de do diretório: /backups\n\
> Para o site: $nome_do_site.
> $texto"


        echo -e "\n\
> Backups encontrados:\n\
----------------------"
            echo -e "$backups_encontrados"
        read -p "Pressione ENTER para continuar para o próximo site..." 
done;;



    # Esta opção permite ao utilizador percorrer ver todos os backups encontrados dentro
    # de /var/www.
    3) echo -e "\
\n\n\n\n-----------------\n\
TODOS OS BACKUPS \n\
É percorrido o diretório /backups por todos os ficheiros de backup disponíveis.\n
São apresentados de ordem decrescente.\n"        
        read -p "Pressione ENTER para continuar..."
            # Conta e lista todos os backups existentes, ordenados de forma decrescente.
            # Formata ainda o texto que representa a quantidade de backups encontrados.
            num_backups_encontrados=$(find /backups -type f | wc -l)
            backups_encontrados=$(find /backups -type f | sort -nr)
            texto=$(FormatarContagemBackups "$num_backups_encontrados")
        

        # Apresenta a quantidade de backups encontrados.
        # Seguidamente, são listados TODOS os ficheiros de backup.
        echo -e "\
\n\n\n\n----------------------------------------------\n\
Dentro de do diretório: /backups\n\
> $texto"


        echo -e "\n\
> Backups encontrados:\n\
----------------------"
        echo -e "$backups_encontrados"
        read -p "Pressione ENTER para continuar..." ;;

        # Esta opção retorna para o menu.
        4)  ;;

        # Caso o input do utilizador não seja válido, o utilizador retorna ao menu.
        *) echo -e "\
\n\n\n\n-----------------------------------------------------\n\
>>[ERRO]<<\n\
Opção inválida.\n\
Terminando operações..."
            read -p "Pressione ENTER para continuar..."
    esac

    echo -e "\
\n\n\n\n----------\n\
Terminada as operações de leitura de backups!"

    read -p "Pressione ENTER para voltar para o menu..."


    # Como definido no início da função, caso não exista o diretório /backups 
    # é enviado uma mensagem de erro que retorna o utilizador ao menu.
    else
        echo -e "\
\n\n\n>>[ERRO]<<\n\
Não existe o diretório /backups!\n\
Por favor crie o diretório /backups OU corra a operação de criação de backups!"
        read -p "Pressione ENTER para continuar para o menu..."
        
    fi

}






#---------------------------------------------------------------#
#---------------------------------------------------------------#






# Função para criar backups dos websites em /var/www
# Esta função verifica se o diretório /backups existe e, se não, cria-o.
# Depois percorre cada diretório em /var/www/ e permite ao utilizador
# escolher se quer fazer backup de cada site individualmente.
Criar_backups()
{  
    echo -e "\n\n\n\n\
CRIAÇÃO DE BACKUPS\n\
------------------"
    # Verifica se existe o diretório /backups, se existir, continua a operação.
    if [ -d /backups ]; 
        then echo -e "\
>>[SUCESSO!]<<\n\
Foi encontrado diretório /backups."
        read -p  "Pressione ENTER para continuar a operação..."
    else
    # Por outro lado, se não existir o diretório /backups, ele cria o diretório.
        echo -e "\
>>[ERRO]<<\n\
Não existe o diretório /backups!\n\
Este diretório será criado!"
        mkdir -p /backups
        read -p "Pressione ENTER para continuar a operação..."
    fi
    # Criação da variável utilizada para guardar a data que será utilizada para
    # dar um nome ao ficheiro de backups.
    data=$(date +%Y-%m-%d_%H-%M-%S)




    # Inicializadas as variáveis para o relatório de email
    # Adiciona cabeçalho ao relatório
    texto_para_mail=""
    texto_para_mail+="\
RELATÓRIO DE BACKUP DE WEBSITES\n
--------------------------------\n\n
Data e hora: $data\n\n\
DETALHES DOS BACKUPS:\n\
--------------------\n\n"




    # Criação do loop que percorre diretório a diretório dos sites.
    for diretorio in /var/www/*/
    do
        nome_do_site=$(basename "$diretorio")
        echo -e "\n\n\n\n\nGostaria de fazer um backup do site: $nome_do_site?"
        echo -e "1) Sim."
        echo -e "2) Não e continuar para o próximo."
        echo -e "3) Voltar para o menu."
        read -p "->" var
            input_utilizador=$var
            
            # Esta opção cria um backup do diretório do site selecionado.
            case $input_utilizador in
            1)  
                # Cria o backup do site atual usando tar com compressão bzip2.
                # O backup é salvo em /backups com o nome do site e a data atual.
                tar -cjf /backups/"$nome_do_site"-"$data".tar.bz2 -C "/var/www" "$nome_do_site"
                
                #Apresenta as mensagens do resultado da operação do backup. Seguido da verificação
                # de backups antigos.
                echo -e "
 \n\n\n\n-----------------------------------------------------\n\
>>[SUCESSO]<<\n\"
Criado o backup dos ficheiros do site: $nome_do_site.\n
Prosseguindo com a limpeza de backups antigos do $nome_do_site!\n"


            # Conta quantos backups antigos existem (a partir do 6º mais antigo) e formata texto para
            # a quantidade de backups encontrados.
            num_backups_antigos=$(find /backups -type f| grep "/$nome_do_site-"| sort -n | tail -n +6| wc -l)
            texto=$(FormatarContagemBackupsAntigos "$num_backups_antigos")            
            echo -e "$texto"


            # Encontra e remove os backups mais antigos (mantém apenas os 5 mais recentes)
            backups_antigos=$(find /backups -type f | grep "/$nome_do_site-" | sort -nr | tail -n +6)
            
            # Criação do texto para o Email com o relatório das operações.
            texto_para_mail+="Foi criado um backup para o site: $nome_do_site.\n"
            texto_para_mail+="O ficheiro backup criado tem o nome de: $nome_do_site-$data.tar.bz2\n"
            texto_para_mail+="Backups antigos removidos: $num_backups_antigos\n"        
            texto_para_mail+="Foram removidos os seguintes backups:\n$backups_antigos\n\n"

            # Começa um loop, que para cada backup antigo que encontrou com a listagem feita com
            # a variável backups_antigos, é apagado o backup.
            for backup in $backups_antigos; 
            do
            echo "$backup"
                    rm -f "$backup"
            done
            read -p "Pressione ENTER para continuar..."
           ;;

            # Esta opção salta a criação do backup e procede para o próximo site.
            2)  echo -e "\n\
Não foi feito backup para o site: $nome_do_site\n"
                read -p "Pressione ENTER para continuar...";;

            # Esta opção quebra o loop e retorna ao menu principal.
            3) break;;

            # Caso o input do utilizador não seja válido, o programa salta para o próximo site a ser feito backups.
            *)  echo -e "\
\n\n\n\n-----------------------------------------------------\n\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar..."
                ;;
        
        esac
    done
    echo -e "\
\n\n\nGostaria de enviar um mail do relatório feito?\n\
1) Sim\n\
2) Não\n"
            read -p "->" var
            input_utilizador=$var
            case $input_utilizador in

            1)  echo -e "\n------------\nA enviar um mail..."
                read -p "Insira o destinário: " var
                mail_destinatario=$var
                echo -e "$texto_para_mail" > "$mail_enviado"
                echo -e "Subject: Relatório dos Backups realizados - $data\nTo: $mail_destinatario\nFrom: $mail_remetente\n\n$(cat $mail_enviado)" | msmtp "$mail_destinatario"
                # echo "$mail_enviado" | mail -s "Relatório dos Backups realizados - $data" "$mail_destinatario"
                echo -e "Email enviado para $mail_destinatario";;
            2) echo -e "\n\nNão será enviado um email.";;

            esac
    echo -e "\
\n\n\n\n----------\n\
Terminada todas as operações de backups!"
    read -p "Pressione ENTER para voltar para o menu..."


}


#---------------------------------------------------------------#
#---------------------------------------------------------------#


# Função para restaurar backups dos websites
# Esta função verifica se o diretório /backups existe e, em caso afirmativo,
# permite ao utilizador restaurar backups para os websites existentes.
Restaurar_backups()
    {     echo -e "\n\n\n\n\
RESTAURAÇÃO DE BACKUPS\n\
----------------------"
    # Começa por verificar se o diretório /backups existe.
    # Caso exista, continua as operações.
    if [ -d /backups ]; 
    then echo -e "\
\n\n\n>>[SUCESSO!]<<\n\
Foi encontrado diretório /backups."
        read -p  "Pressione ENTER para continuar a operação..."
        

        # Conta o número total de backups existentes e formata o texto
        # para a quantidade de backups encontrados.
        backups_guardados=$(find /backups -type f -wholename "/backups/*" | wc -l)
        texto=$(FormatarContagemBackups "$backups_guardados")

        # Apresenta a quantidade de backups na totalidade que foram encontrados.
            echo -e "\n\n\n\
----------------------------------------------------------\n\
$texto\n\
A percorrer o diretório /backups por backups - site a site."
    read -p "Pressione ENTER para continuar..."

        # Começa um loop que percorre cada diretório de sites em /var/www/ e procura por backups correspondentes
        # ao seu nome.
        for diretorio in /var/www/*/
        do
            nome_do_site=$(basename "$diretorio")
            # Procura pela QUANTIDADE de backups que correspondem ao nome do site atual e formata o respetivo texto
            # para a quantidade de backups encontrados.
            num_backups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | wc -l)
            
            # LISTA os backups com números de linha para facilitar a seleção como printbackups_guardados_site.
            # Por outro lado, backups_guardados_site será utilizado para as operações entre variáveis.
            printbackups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | sort -nr| nl)
            backups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | sort -nr)
            texto=$(FormatarContagemBackups "$num_backups_guardados_site")
            
            # Apresenta o utilizador com o menu, informando qual o site que está a ser percorrido no momento
            # e a quantidade de backups que foram encontrados para ele.
            echo -e "\
\n\n\n---------------------------------------------\n\
Site    -> $nome_do_site\n\
$texto"

            echo -e "Gostaria de restaurar os backups encontrados?"
            echo -e "1) Sim."
            echo -e "2) Não e continuar para o próximo."
            echo -e "3) Voltar para o menu."
    
            read -p "->" var
            input_utilizador=$var
            case $input_utilizador in

                # Esta opção permite o restaurar um dos diretórios dos sites
                # através de um backup criado.
                
                # Começa por manter na apresentação ao utilizador o nome do site
                # em que se estão a realizar as operações, seguido por imprimir
                # a lista de todos os backups encontrados COM uma coluna que os númera cada entrada.

                1)  echo -e "\

\n\n\n---------------------------------------------\n\
Site    -> $nome_do_site\n\
Backups encontrados:\n\
$printbackups_guardados_site\
\n---------------------------"

                # Verificação se existem ou não backups criados para o site.
                # SE, o número de backups do site que está a ser percorrido é diferente de 0 continua as operações.
                # Se isso não se verificar, salta para o próximo site.

                if [ "$num_backups_guardados_site" -ne 0 ]; then
                    
                    # Tendo os backups listados a ser apresentados com números que identificam a 
                    # linha, o utilizador é esperado inserir o número correspondente ao backup
                    # que quer restaurar.
                    read -p "Insira número do backup que quer restaurar." var
                    input_utilizador=$var
                    
                    # Se a opção do utilizador encontra-se entre 1 e o número de backups encontrados,
                    # ou seja, o número de backups apresentados ao utilizador, são continuadas as operações.
                    if [ "$input_utilizador" -le "$num_backups_guardados_site" ] && [ "$input_utilizador" -ne 0 ] && [ "$input_utilizador" -gt 0 ]; then 
                    
                        # Seleciona o backup escolhido pelo utilizador.
                        backup_selecionado=$(echo "$backups_guardados_site" | sed -n "${input_utilizador}p")
                        # Remove o diretório atual do site para evitar conflitos.
                        rm -rf "$diretorio"
                        # Extrai o backup para o diretório /var/www, finalizando o processo.
                        tar -xvf "$backup_selecionado" -C /var/www
                        # Imprime a mensagem de resultado a informar que foi realizado o backup com sucesso.
                        echo -e "\
>>[SUCESSO]<<\n\
Backup foi restaurado com sucesso!"
                        read -p "Pressione ENTER para continuar..."
                    # Caso o utilizador não insira um número que associado a um backup, 
                    # é imprimida uma mensagem de erro e continuado as operações de restauro 
                    # para o próximo site.
                    else 
                        echo -e "\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..." 
                        read -p "Pressione ENTER para continuar..."
                    fi
                else
                    # Caso não sejam encontrados backups para o site a ser percorrido,
                    # é continuado as operações de restauro para o próximo site.
                echo -e "\
Não foram encontrados backups para este site.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar..."
                fi
;;
                # Esta opção salta para o próximo site onde-se poderão continuar as operações
                # de restauro de backup.
                2) echo -e "A saltar para o próximo site."
                    read -p "Pressione ENTER para continuar para o próximo site.";;
        
                # Esta opção quebra o loop e retorna o utilizador ao menu.
                3) break ;;

                # Caso o utilizador não insira nenhuma das opções corretas, o programa
                # salta para o próximo site para continuar as operações de restauro de backup.
                *) echo -e "\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar...";;
        esac    
    done
        else

        # Caso o diretório /backups não exista, é fornecida uma Mensagem de erro
        echo -e "\
\n\n\n>>[ERRO]<<\n\
Não existe o diretório /backups!\n\
Por favor crie o diretório /backups OU corra a operação de criação de backups!"
        read -p "Pressione ENTER para continuar para o menu..."    
    fi

        echo -e "\
\n\n\n\n----------\n\
Terminada todas as operações de restaurar backups!"
    read -p "Pressione ENTER para voltar para o menu..."

}







#---------------------------------------------------------------#
#---------------------------------------------------------------#







# Função para apagar backups específicos
# Esta função verifica se o diretório /backups existe e, em caso afirmativo,
# permite ao utilizador apagar backups específicos para cada website.
Apagar_Backups()
    { 
        echo -e "\n\n\n\n\
APAGAR BACKUPS\n\
--------------"
        # Caso /backups exista, procede com as operações.
        if [ -d /backups ]; 
        then echo -e "\
\n\n\n>>[SUCESSO!]<<\n\
Foi encontrado diretório /backups."
        read -p  "Pressione ENTER para continuar a operação..."
        

        # Conta o número total de backups existentes e novamente formata o texto
        # tendo em conta a quantidade encontrada.
        backups_guardados=$(find /backups -type f -wholename "/backups/*" | wc -l)
        texto=$(FormatarContagemBackups "$backups_guardados")
        
        # Apresenta a quantidade de backups armazenados em /backups na totalidade.
        echo -e "\n\n\n\
----------------------------------------------------------\n\
$texto\n\
A percorrer o diretório /backups por backups - site a site."

        # Percorre cada diretório em /var/www/ e procura por backups correspondentes
        for diretorio in /var/www/*
        do
            nome_do_site=$(basename "$diretorio")
            # Procura pela QUANTIDADE de backups que correspondem ao nome do site atual
            num_backups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | wc -l)
            # Lista os backups com números de linha para facilitar a seleção usando lógica idêntica
            # à função de Restauro_Backups.
            printbackups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | sort -nr | nl)
            backups_guardados_site=$(find /backups -type f -wholename "/backups/*" | grep "/$nome_do_site-" | sort -nr)
            texto=$(FormatarContagemBackups "$num_backups_guardados_site")
            
            # Apresentado o nome do site a ser percorrido mais a quantidade de backups encontrados,
            # correspondentes a ele para além de ser apresentado um menu.
            echo -e "\
\n\n\n---------------------------------------------\n\
Site    -> $nome_do_site\n\
$texto"

            echo -e "Gostaria de apagar um dos backups encontrados?"
            echo -e "1) Sim."
            echo -e "2) Não e continuar para o próximo."
            echo -e "3) Voltar para o menu."
    
            read -p "->" var
            input_utilizador=$var
            case $input_utilizador in
    
                # Esta opção permite uma série de operações que
                # deixam o utilizador apagar um backup específico 
                # do site que estiver a ser percorrido.
                
                # É apresentado o nome do site e a lista de ficheiros de backups
                # numerada.
                1)  echo -e "\
\n\n\n---------------------------------------------\n\
Site    -> $nome_do_site\n\
Backups encontrados:\n\
$printbackups_guardados_site\
\n---------------------------"
                # Verifica se existem backups para este site, se existirem
                # continua as operações.
                if [ "$num_backups_guardados_site" -ne 0 ]; then
                    read -p "Insira número do backup que quer apagar: " var
                    input_utilizador=$var
    
                    #SE a opção do utilizador encontra-se entre 1 e o número de backups encontrados.
                    if [ "$input_utilizador" -le "$num_backups_guardados_site" ] && [ "$input_utilizador" -ne 0 ] && [ "$input_utilizador" -gt 0 ]; then 
                    
                        # Seleciona o backup escolhido pelo utilizador.
                        backup_selecionado=$(echo "$backups_guardados_site" | sed -n "${input_utilizador}p")
                        # Remove o backup selecionado
                        rm -rf "$backup_selecionado"
                        # É apresentado a mensagem de sucesso depois da operação de realizada. 
                        echo -e "\
>>[SUCESSO]<<\n\
Backup foi apagado com sucesso!"
                        read -p "Pressione ENTER para continuar..."
                    else 
                    # Por outro lado, se o utilizador não inserir nenhum um número correspondente a
                    # um backup da lista apresentado, é fornecida uma mensagem de erro que salta
                    # as operações de apagar backups para o próximo site.
                        echo -e "\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..." 
                        read -p "Pressione ENTER para continuar..."
                    fi
                else
                # Caso nem sejam encontrados backups, salta para o próximo site
                # e continuam-se as operações.
                echo -e "\
Não foram encontrados backups para este site.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar..."
                fi
;;    
                # Esta opção salta para o próximo site caso o utilizador não queira apagar
                # nenhum backup.
                2) echo -e "A saltar para o próximo site."
                    read -p "Pressione ENTER para continuar para o próximo site.";;
                
                # Esta opção quebra o loop e retorna o utilizador ao menu.
                3) break ;;

                # Caso o utilizador não insira nenhuma opção válida, é saltado para o próximo site
                # e continuado as operações.
                *) echo -e "\
>>[ERRO]<<\n\
Opção inválida.\n\
A saltar para o próximo site..."
                read -p "Pressione ENTER para continuar...";;
        esac    
    done

        else
        # Caso o diretório /backups não exista é fornecida uma mensagem de erro.
        echo -e "\
\n\n\n>>[ERRO]<<\n\
Não existe o diretório /backups!\n\
Por favor crie o diretório /backups OU corra a operação de criação de backups!"
        read -p "Pressione ENTER para continuar para o menu..."    
    fi
        
        
        echo -e "\
\n\n\n\n----------\n\
Terminada todas as operações de apagar backups!"
    read -p "Pressione ENTER para voltar para o menu..."

    
}


#---------------------------------------------------------------#
#---------------------------------------------------------------#



# Função para sair do programa
# Esta função altera a variável menu_estado para 0, o que faz com que
# o loop principal do menu termine, encerrando assim o programa.
Sair_do_programa()
    {
    menu_estado=0
    echo -e "\n\n\n\nSAIU DO PROGRAMA"
}




#FUNÇÃO DO MENU PRINCIPAL
#------------------------
#Esta função utiliza a variável definida no ínico
#"menu_estado", para que esteja ativa num loop.
menu_principal()
{
    #Forçamos o script correr como utilizador utilizando o $EUID,
    # effective user ID, que representa o utilizador a EXECUTAR o 
    # o shellscript. Neste caso, será o utilizador.
    
    # Forçamos a utilização de superutilizador devido a possíveis
    # erros de criação de diretórios como o /backups/ por causa
    # de permissões.

    if [ "$EUID" -ne 0 ] 
    then echo -e "\n>>[ERRO]<<\n\
>>Este script deve ser executado como superutilizador.<<\n\
Por favor corra o shellscript com: sudo ./PLACEHOLDER..."
    read -p "Pressione ENTER para sair do programa..."
    exit 1
    fi
    
    # Loop principal do menu que continua enquanto menu_estado for igual a 1
    while   [ "$menu_estado" -eq 1 ]
    do
        # Exibe o menu principal com as opções disponíveis
        echo -e "\n\n\n\n\n\nBem Vindo ao programa de Backups de Websites!"
        echo -e "---------------------------------------------"
        echo -e "\
Digite um número para realizar uma operação:\n\
1. Listar todos Ficheiros Existentes\n\
2. Listar todos Backups Existentes\n\
3. Criar um novo Backup dos Websites\n\
4. Restaurar um Backup\n\
5. Apagar um backup\n\
6. Sair"
    #    echo -e "->$menu_ultimo_input"    

        # Lê a opção escolhida pelo utilizador
        read -p "->" var
        menu_input=$var
        
        # Executa a função correspondente à opção escolhida
        case $menu_input in 
            1) Listar_ficheiros;;
            2) Listar_backups;;
            3) Criar_backups;;
            4) Restaurar_backups;;
            5) Apagar_Backups;;
            6) Sair_do_programa ;;
            *) echo -e "
\n>>[ERRO]<<\n\
>>Valor inserido não foi aceite.<<\n\
Pressione ENTER para continuar..."

            read 
            ;; 
        esac
    done
}

# Inicia o programa chamando a função do menu principal
menu_principal
