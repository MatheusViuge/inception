#!/usr/bin/env bash

# ============================================================
# INCEPTION VM SETUP
#
# Uso:
#   ./replace_user.sh <login>
#
# Exemplo:
#   ./replace_user.sh gda-conc
#
# O script:
#   1. Valida a pasta do projeto.
#   2. Entra como root usando su.
#   3. Instala make, sudo, Docker e Docker Compose.
#   4. Testa o acesso sudo existente e só configura se necessário.
#      Se não estiver, adiciona o usuário ao grupo sudo e
#      cria/valida /etc/sudoers.d/<usuario>.
#   5. Adiciona o usuário ao grupo docker.
#   6. Substitui "mviana" e "mviana-v" pelo novo login.
#   7. Configura <login>.42.fr em /etc/hosts.
#   8. Copia env.example para srcs/.env.
#   9. Cria /home/<login>/data/mariadb e wordpress.
#  10. Valida toda a configuração.
#  11. Reinicia a VM somente se todos os testes passarem.
#
# Quando "su" pedir a senha de root, use a senha configurada
# na VM. Neste ambiente, a senha esperada é: 123
#
# A senha NÃO é armazenada no script.
# ============================================================

set -Eeuo pipefail

# ============================================================
# TRATAMENTO DE ERROS
# ============================================================

trap '
	status=$?
	echo
	echo "========================================="
	echo " ERRO DURANTE A CONFIGURAÇÃO"
	echo " Linha: $LINENO"
	echo " Código: $status"
	echo "========================================="
	echo
	echo "A VM NÃO será reiniciada."
	exit "$status"
' ERR

die()
{
	echo
	echo "ERRO: $*" >&2
	echo "A VM NÃO será reiniciada." >&2
	exit 1
}

# ============================================================
# CONFIGURAÇÃO
# ============================================================

# Casa tanto:
#   mviana
# quanto:
#   mviana-v
OLD_REGEX='mviana(-v)?'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$ROOT_DIR/$(basename "$0")"
SCRIPT_NAME="$(basename "$0")"

# ============================================================
# PRIMEIRA EXECUÇÃO — USUÁRIO NORMAL
# ============================================================
#
# A primeira chamada esperada é:
#
#   ./replace_user.sh gda-conc
#
# Se ainda não somos root, guardamos o usuário atual e o login
# recebido, montamos de forma segura o comando que será passado
# ao "su" e executamos ESTE MESMO script novamente como root.
#
# A segunda execução será:
#
#   replace_user.sh --root <usuario_original> <novo_login>
#
# O uso de printf '%q' corrige o problema anterior de perda ou
# interpretação incorreta dos argumentos dentro do "su -c".

if [ "$EUID" -ne 0 ]; then

	if [ "$#" -ne 1 ]; then
		echo "Uso: $0 <novo_login>"
		echo "Exemplo: $0 gda-conc"
		exit 1
	fi

	NEW_LOGIN="$1"
	TARGET_USER="$(id -un)"

	if ! [[ "$NEW_LOGIN" =~ ^[a-zA-Z0-9-]+$ ]]; then
		die "Login inválido: $NEW_LOGIN"
	fi

	if [ ! -d "$ROOT_DIR/srcs" ]; then
		die "Diretório srcs não encontrado em: $ROOT_DIR"
	fi

	if [ ! -f "$ROOT_DIR/env.example" ]; then
		die "env.example não encontrado em: $ROOT_DIR"
	fi

	echo
	echo "========================================="
	echo " INCEPTION VM SETUP"
	echo "========================================="
	echo "Usuário da VM : $TARGET_USER"
	echo "Novo login     : $NEW_LOGIN"
	echo
	echo "Entrando como root..."
	echo "Quando o su pedir Password, informe a senha root."
	echo

	printf -v ROOT_COMMAND '%q ' \
		"$SCRIPT_PATH" \
		"--root" \
		"$TARGET_USER" \
		"$NEW_LOGIN"

	exec su root -c "exec $ROOT_COMMAND"
fi

# ============================================================
# SEGUNDA EXECUÇÃO — ROOT
# ============================================================

if [ "${1:-}" != "--root" ] || [ "$#" -ne 3 ]; then
	die "Parâmetros internos inválidos. Esperado: --root <usuario> <login>"
fi

TARGET_USER="$2"
NEW_LOGIN="$3"

if [ "$EUID" -ne 0 ]; then
	die "A segunda etapa precisa ser executada como root."
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
	die "O usuário '$TARGET_USER' não existe."
fi

if ! [[ "$NEW_LOGIN" =~ ^[a-zA-Z0-9-]+$ ]]; then
	die "Login inválido: $NEW_LOGIN"
fi

TARGET_GROUP="$(id -gn "$TARGET_USER")"
DOMAIN="${NEW_LOGIN}.42.fr"

ENV_EXAMPLE="$ROOT_DIR/env.example"
ENV_TARGET="$ROOT_DIR/srcs/.env"

DATA_DIR="/home/$NEW_LOGIN/data"
SUDOERS_FILE="/etc/sudoers.d/$TARGET_USER"

# ============================================================
# VALIDAR ESTRUTURA DO PROJETO ANTES DE ALTERAR A VM
# ============================================================

[ -d "$ROOT_DIR/srcs" ] \
	|| die "Diretório srcs não encontrado em: $ROOT_DIR"

[ -f "$ENV_EXAMPLE" ] \
	|| die "env.example não encontrado em: $ROOT_DIR"

command -v apt-get >/dev/null 2>&1 \
	|| die "apt-get não encontrado. Este script foi preparado para Debian/Ubuntu."

echo
echo "========================================="
echo " CONFIGURAÇÃO INICIADA COMO ROOT"
echo "========================================="
echo "Usuário Linux : $TARGET_USER"
echo "Grupo         : $TARGET_GROUP"
echo "Login 42      : $NEW_LOGIN"
echo "Domínio       : $DOMAIN"
echo "Projeto       : $ROOT_DIR"
echo

# ============================================================
# FUNÇÃO — VERIFICAR SE O SUDO JÁ ESTÁ CONFIGURADO
# ============================================================
#
# Retorna sucesso (0) somente se o sudo reconhecer que o
# TARGET_USER possui privilégios configurados.
#
# Isso verifica a configuração efetiva do sudo; não basta apenas
# existir o comando "sudo" ou o usuário aparecer no grupo.
#
# Como esta parte do script já roda como root, podemos consultar
# diretamente as permissões do outro usuário com:
#
#   sudo -l -U <usuario>
#
# Se essa verificação passar, a etapa de configuração do sudo será
# completamente ignorada.

sudo_is_configured()
{
	if ! command -v sudo >/dev/null 2>&1; then
		return 1
	fi

	if sudo -l -U "$TARGET_USER" >/dev/null 2>&1; then
		return 0
	fi

	return 1
}


# ============================================================
# 1/9 — ATUALIZAR APT
# ============================================================

echo "[1/9] Atualizando lista de pacotes..."
apt-get update

# ============================================================
# 2/9 — INSTALAR MAKE, SUDO E DOCKER
# ============================================================

echo
echo "[2/9] Instalando make, sudo e Docker..."

apt-get install -y \
	make \
	sudo \
	docker.io

# ============================================================
# 3/9 — INSTALAR DOCKER COMPOSE
# ============================================================

echo
echo "[3/9] Instalando Docker Compose..."

if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
	echo "Pacote encontrado: docker-compose-plugin"
	apt-get install -y docker-compose-plugin

elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then
	echo "Pacote encontrado: docker-compose-v2"
	apt-get install -y docker-compose-v2

elif apt-cache show docker-compose >/dev/null 2>&1; then
	echo "Pacote encontrado: docker-compose"
	apt-get install -y docker-compose

else
	die "Nenhum pacote Docker Compose compatível foi encontrado via apt."
fi

# ============================================================
# 4/9 — VERIFICAR / CONFIGURAR SUDO
# ============================================================
#
# IMPORTANTE:
#
# Se sudo_is_configured retornar sucesso, esta etapa NÃO executa:
#
#   /usr/sbin/usermod -aG sudo ...
#   criação de /etc/sudoers.d/...
#   chmod do sudoers
#
# Ou seja: se o usuário já possui sudo válido, não alteramos nada.
#
# Só configuramos o sudo quando a verificação efetiva falhar.

echo
echo "[4/9] Verificando configuração existente do sudo..."

if sudo_is_configured; then

	echo "OK: $TARGET_USER já possui acesso sudo."
	echo "Pulando completamente a configuração do sudo."

else

	echo "Sudo ainda não está configurado para $TARGET_USER."
	echo "Configurando agora..."

	# Adiciona ao grupo padrão de administradores do Debian.
	if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "sudo"; then
		/usr/sbin/usermod -aG sudo "$TARGET_USER"
		echo "Usuário adicionado ao grupo sudo."
	else
		echo "Usuário já estava no grupo sudo."
	fi

	# Cria a regra individual somente porque a verificação efetiva
	# mostrou que o usuário ainda não possuía sudo funcional.
	#
	# Primeiro criamos um arquivo temporário, validamos com visudo
	# e só depois instalamos em /etc/sudoers.d/.
	SUDOERS_TMP="$(mktemp)"

	cat > "$SUDOERS_TMP" <<EOF
$TARGET_USER ALL=(ALL:ALL) ALL
EOF

	chmod 440 "$SUDOERS_TMP"

	if ! visudo -cf "$SUDOERS_TMP" >/dev/null 2>&1; then
		rm -f "$SUDOERS_TMP"
		die "A configuração sudoers gerada é inválida."
	fi

	install -o root -g root -m 440 \
		"$SUDOERS_TMP" \
		"$SUDOERS_FILE"

	rm -f "$SUDOERS_TMP"

	# Agora o sudo precisa reconhecer o usuário.
	if ! sudo_is_configured; then
		die "O sudo foi configurado, mas $TARGET_USER ainda não possui acesso."
	fi

	echo "Sudo configurado com sucesso."

fi

# ============================================================
# 5/9 — CONFIGURAR DOCKER SEM SUDO
# ============================================================

echo
echo "[5/9] Configurando Docker para $TARGET_USER..."

if ! getent group docker >/dev/null 2>&1; then
	groupadd docker
fi

/usr/sbin/usermod -aG docker "$TARGET_USER"

systemctl enable --now docker

echo "Usuário adicionado ao grupo docker."

# ============================================================
# 6/9 — SUBSTITUIR LOGIN NOS ARQUIVOS DO PROJETO
# ============================================================

echo
echo "[6/9] Substituindo mviana/mviana-v por $NEW_LOGIN..."

ALTERED_FILES=0

while IFS= read -r -d '' file; do

	sed -E -i "s|$OLD_REGEX|$NEW_LOGIN|g" "$file"

	# Preserva o projeto como pertencente ao usuário original.
	chown "$TARGET_USER:$TARGET_GROUP" "$file"

	echo "Alterado: ${file#$ROOT_DIR/}"

	ALTERED_FILES=$((ALTERED_FILES + 1))

done < <(
	grep -rIlZ \
		--exclude-dir=".git" \
		--exclude="$SCRIPT_NAME" \
		-E "$OLD_REGEX" \
		"$ROOT_DIR" 2>/dev/null || true
)

echo "Arquivos alterados: $ALTERED_FILES"

# ============================================================
# 7/9 — CONFIGURAR /etc/hosts
# ============================================================
#
# Remove uma entrada anterior EXATA do domínio, caso exista,
# preservando todas as outras linhas do /etc/hosts.
#
# Depois adiciona:
#
#   127.0.0.1    <login>.42.fr

echo
echo "[7/9] Configurando /etc/hosts..."

HOSTS_TMP="$(mktemp)"

cleanup_hosts_tmp()
{
	rm -f "$HOSTS_TMP"
}

trap cleanup_hosts_tmp EXIT

while IFS= read -r line || [ -n "$line" ]; do

	# Pega somente a parte anterior a um comentário.
	#
	# Exemplo:
	#
	# 127.0.0.1 localhost # comentário
	#
	# vira temporariamente:
	#
	# 127.0.0.1 localhost
	content="${line%%#*}"

	# Divide a linha em campos somente para verificar
	# se o domínio já existe nela.
	read -r -a fields <<< "$content"

	found=0

	# O primeiro campo normalmente é o IP.
	# A partir do segundo ficam os hostnames.
	for ((i = 1; i < ${#fields[@]}; i++)); do

		if [ "${fields[$i]}" = "$DOMAIN" ]; then
			found=1
			break
		fi

	done

	# Se esta linha NÃO contém exatamente o domínio,
	# preservamos ela sem nenhuma alteração.
	if [ "$found" -eq 0 ]; then
		printf '%s\n' "$line" >> "$HOSTS_TMP"
	fi

done < /etc/hosts

# Adiciona a entrada correta ao final.
printf '127.0.0.1\t%s\n' "$DOMAIN" >> "$HOSTS_TMP"

# Como já estamos executando como root,
# podemos substituir o conteúdo do arquivo diretamente.
cat "$HOSTS_TMP" > /etc/hosts

rm -f "$HOSTS_TMP"

trap - EXIT

echo "Adicionado:"
echo "  127.0.0.1	$DOMAIN"

# ============================================================
# 8/9 — CRIAR srcs/.env
# ============================================================

echo
echo "[8/9] Criando srcs/.env..."

cp "$ENV_EXAMPLE" "$ENV_TARGET"
chown "$TARGET_USER:$TARGET_GROUP" "$ENV_TARGET"

echo "Criado: $ENV_TARGET"

# ============================================================
# 9/9 — CRIAR DIRETÓRIOS DOS DADOS
# ============================================================

echo
echo "[9/9] Criando diretórios dos volumes..."

mkdir -p \
	"$DATA_DIR/mariadb" \
	"$DATA_DIR/wordpress"

chown -R "$TARGET_USER:$TARGET_GROUP" "/home/$NEW_LOGIN"

echo "Criado:"
echo "  $DATA_DIR/mariadb"
echo "  $DATA_DIR/wordpress"

# ============================================================
# VALIDAÇÃO FINAL
# ============================================================
#
# O reboot só será alcançado se TODOS os testes abaixo
# passarem.

echo
echo "========================================="
echo " VALIDANDO CONFIGURAÇÃO"
echo "========================================="

echo -n "[TESTE] make.................... "
command -v make >/dev/null 2>&1 \
	|| die "make não está instalado."
echo "OK"

echo -n "[TESTE] Docker.................. "
command -v docker >/dev/null 2>&1 \
	|| die "Docker não está instalado."
echo "OK"

echo -n "[TESTE] Docker Compose.......... "

if docker compose version >/dev/null 2>&1; then
	COMPOSE_COMMAND="docker compose"
	echo "OK"
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE_COMMAND="docker-compose"
	echo "OK"
else
	die "Docker Compose não está disponível."
fi

echo -n "[TESTE] Docker daemon........... "
systemctl is-active --quiet docker \
	|| die "O serviço Docker não está ativo."
echo "OK"

# Não exigimos que exista especificamente:
#
#   /etc/sudoers.d/<usuario>
#
# porque, se o sudo já estava corretamente configurado antes
# do script, nós propositalmente não alteramos essa configuração.
#
# Aqui testamos o que realmente importa: o usuário possui
# permissão válida de sudo.

echo -n "[TESTE] Acesso sudo............. "

sudo_is_configured \
	|| die "$TARGET_USER não possui acesso sudo."

echo "OK"

echo -n "[TESTE] Grupo docker............ "
id -nG "$TARGET_USER" \
	| tr ' ' '\n' \
	| grep -qx "docker" \
	|| die "$TARGET_USER não está no grupo docker."
echo "OK"

echo -n "[TESTE] Docker sem sudo......... "

if su -s /bin/sh "$TARGET_USER" \
	-c "docker info >/dev/null 2>&1"; then
	echo "OK"
else
	die "O usuário '$TARGET_USER' ainda não consegue usar Docker diretamente."
fi

echo -n "[TESTE] /etc/hosts.............. "

HOST_OK=0

while IFS= read -r line || [ -n "$line" ]; do

	content="${line%%#*}"

	read -r -a fields <<< "$content"

	if [ "${fields[0]:-}" != "127.0.0.1" ]; then
		continue
	fi

	for ((i = 1; i < ${#fields[@]}; i++)); do

		if [ "${fields[$i]}" = "$DOMAIN" ]; then
			HOST_OK=1
			break 2
		fi

	done

done < /etc/hosts

if [ "$HOST_OK" -eq 1 ]; then
	echo "OK"
else
	die "$DOMAIN não está corretamente configurado em /etc/hosts."
fi

echo -n "[TESTE] srcs/.env............... "
[ -f "$ENV_TARGET" ] \
	|| die "srcs/.env não existe."
echo "OK"

echo -n "[TESTE] cópia do env.example.... "
cmp -s "$ENV_EXAMPLE" "$ENV_TARGET" \
	|| die "srcs/.env é diferente de env.example."
echo "OK"

echo -n "[TESTE] volume MariaDB.......... "
[ -d "$DATA_DIR/mariadb" ] \
	|| die "Diretório do MariaDB não foi criado."
echo "OK"

echo -n "[TESTE] volume WordPress........ "
[ -d "$DATA_DIR/wordpress" ] \
	|| die "Diretório do WordPress não foi criado."
echo "OK"

echo -n "[TESTE] login antigo............ "

if grep -rIl \
	--exclude-dir=".git" \
	--exclude="$SCRIPT_NAME" \
	-E "$OLD_REGEX" \
	"$ROOT_DIR" 2>/dev/null \
	| grep -q .; then

	die "Ainda existem ocorrências de mviana/mviana-v no projeto."
fi

echo "OK"

# ============================================================
# RESUMO
# ============================================================

echo
echo "========================================="
echo " TODOS OS TESTES PASSARAM"
echo "========================================="
echo
echo "Usuário Linux : $TARGET_USER"
echo "Login 42      : $NEW_LOGIN"
echo "Domínio       : https://$DOMAIN"
echo "Dados         : $DATA_DIR"
echo ".env          : $ENV_TARGET"
echo
echo "Grupos:"
id "$TARGET_USER"
echo
echo "Versões:"
make --version | head -n 1
docker --version

if [ "$COMPOSE_COMMAND" = "docker compose" ]; then
	docker compose version
else
	docker-compose --version
fi

# ============================================================
# REBOOT
# ============================================================

echo
echo "Sincronizando dados com o disco..."
sync

echo
echo "========================================="
echo " CONFIGURAÇÃO CONCLUÍDA COM SUCESSO"
echo "========================================="
echo
echo "A VM será reiniciada em 5 segundos."
echo

sleep 5

systemctl reboot
