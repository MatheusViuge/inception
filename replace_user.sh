#!/usr/bin/env bash

# ============================================================
# INCEPTION VM SETUP
#
# Uso:
#   ./setup.sh <login>
#
# Exemplo:
#   ./setup.sh lalves-d
#
# O script:
#   1. Entra como root usando su.
#   2. Instala make, sudo, Docker e Docker Compose.
#   3. Adiciona o usuário aos grupos sudo e docker.
#   4. Configura /etc/sudoers.d/.
#   5. Substitui "mviana" e "mviana-v" pelo novo login.
#   6. Configura login.42.fr em /etc/hosts.
#   7. Copia env.example -> srcs/.env.
#   8. Cria os diretórios usados pelos volumes.
#   9. Valida tudo.
#  10. Reinicia a VM somente se tudo estiver correto.
#
# IMPORTANTE:
# Quando o comando "su" pedir a senha do root,
# informe a senha:
#
#   123
#
# A senha NÃO fica armazenada neste arquivo.
# ============================================================


# ============================================================
# CONFIGURAÇÃO DE SEGURANÇA DO BASH
# ============================================================

# -e:
#   encerra o script se um comando falhar.
#
# -E:
#   mantém o tratamento de erros dentro de funções/subshells.
#
# -u:
#   considera erro tentar usar variável não definida.
#
# pipefail:
#   se qualquer comando de um pipeline falhar,
#   o pipeline inteiro será considerado falho.

set -Eeuo pipefail


# ============================================================
# TRATAMENTO DE ERROS
# ============================================================

# Caso algum comando inesperadamente falhe,
# mostramos a linha onde ocorreu.
#
# Como o script será encerrado, ele NÃO chegará ao reboot.

trap '
	echo
	echo "========================================="
	echo " ERRO DURANTE A CONFIGURAÇÃO"
	echo " Linha: $LINENO"
	echo "========================================="
	echo
	echo "A VM NÃO será reiniciada."
' ERR


# ============================================================
# CONFIGURAÇÃO ORIGINAL DO PROJETO
# ============================================================

# Regex (expressão regular) que encontra:
#
#   mviana
#
# e:
#
#   mviana-v
#
# O trecho (-v)? significa que "-v" é opcional.

OLD_REGEX='mviana(-v)?'


# ============================================================
# LOCALIZAÇÃO DO SCRIPT
# ============================================================

# Descobre automaticamente onde o setup.sh está localizado.
#
# Portanto, o script deve ficar na raiz do Inception.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_PATH="$ROOT_DIR/$(basename "$0")"

SCRIPT_NAME="$(basename "$0")"


# ============================================================
# FUNÇÃO DE ERRO
# ============================================================

# Usamos esta função quando encontramos um erro controlado.

die()
{
	echo
	echo "ERRO: $*" >&2
	echo
	echo "A VM NÃO será reiniciada."
	exit 1
}


# ============================================================
# PRIMEIRA EXECUÇÃO
# ============================================================
#
# Normalmente o script será iniciado pelo usuário comum:
#
#   ./setup.sh lalves-d
#
# Nesse momento:
#
#   EUID != 0
#
# porque ainda não somos root.
#
# Então salvamos:
#
#   TARGET_USER = usuário Linux atual
#   NEW_LOGIN   = login passado para o script
#
# e executamos o script novamente através de "su".

if [ "$EUID" -ne 0 ]; then

	# Exige exatamente um argumento.

	if [ "$#" -ne 1 ]; then
		echo "Uso:"
		echo "  $0 <novo_login>"
		echo
		echo "Exemplo:"
		echo "  $0 lalves-d"
		exit 1
	fi

	NEW_LOGIN="$1"

	# Descobre qual usuário iniciou o script.

	TARGET_USER="$(id -un)"

	echo
	echo "========================================="
	echo " INCEPTION VM SETUP"
	echo "========================================="
	echo
	echo "Usuário da VM : $TARGET_USER"
	echo "Novo login     : $NEW_LOGIN"
	echo
	echo "Será necessário acesso root."
	echo
	echo "Quando aparecer:"
	echo
	echo "  Password:"
	echo
	echo "digite a senha root:"
	echo
	echo "  123"
	echo
	echo "========================================="
	echo

	# Reinicia ESTE MESMO SCRIPT como root.
	#
	# Passamos internamente:
	#
	#   --root
	#   usuário original
	#   novo login

	exec su -c \
		"\"$SCRIPT_PATH\" --root \"$TARGET_USER\" \"$NEW_LOGIN\""
fi


# ============================================================
# SEGUNDA EXECUÇÃO — AGORA SOMOS ROOT
# ============================================================

# O script agora espera:
#
#   setup.sh --root <usuario> <login>

if [ "${1:-}" != "--root" ] || [ "$#" -ne 3 ]; then
	die "Parâmetros internos inválidos."
fi


TARGET_USER="$2"
NEW_LOGIN="$3"


# ============================================================
# VALIDAR O USUÁRIO
# ============================================================

# Confirma que o usuário Linux realmente existe.

if ! id "$TARGET_USER" >/dev/null 2>&1; then
	die "O usuário '$TARGET_USER' não existe."
fi


# ============================================================
# VALIDAR LOGIN
# ============================================================

# Permitimos somente:
#
#   letras
#   números
#   hífen
#
# Isso também impede caracteres perigosos de entrarem
# nos comandos sed, paths e /etc/hosts.

if ! [[ "$NEW_LOGIN" =~ ^[a-zA-Z0-9-]+$ ]]; then
	die "Login inválido: $NEW_LOGIN"
fi


# ============================================================
# VARIÁVEIS DERIVADAS
# ============================================================

# Grupo principal do usuário Linux.

TARGET_GROUP="$(id -gn "$TARGET_USER")"


# Domínio obrigatório do Inception.
#
# Exemplo:
#
#   lalves-d
#
# vira:
#
#   lalves-d.42.fr

DOMAIN="${NEW_LOGIN}.42.fr"


# Arquivos relacionados ao .env.

ENV_EXAMPLE="$ROOT_DIR/env.example"

ENV_TARGET="$ROOT_DIR/srcs/.env"


# Diretório utilizado pelos dados persistentes.

DATA_DIR="/home/$NEW_LOGIN/data"


# Arquivo sudoers específico do usuário.

SUDOERS_FILE="/etc/sudoers.d/$TARGET_USER"


# ============================================================
# VALIDAR ESTRUTURA DO INCEPTION
# ============================================================
#
# Fazemos isso ANTES de instalar qualquer coisa.
#
# Assim, se o script estiver no diretório errado,
# não alteramos a VM.

if [ ! -d "$ROOT_DIR/srcs" ]; then
	die "Diretório srcs não encontrado em $ROOT_DIR"
fi


if [ ! -f "$ENV_EXAMPLE" ]; then
	die "env.example não encontrado em $ROOT_DIR"
fi


echo
echo "========================================="
echo " CONFIGURAÇÃO INICIADA COMO ROOT"
echo "========================================="
echo
echo "Usuário Linux : $TARGET_USER"
echo "Grupo         : $TARGET_GROUP"
echo "Login 42      : $NEW_LOGIN"
echo "Domínio       : $DOMAIN"
echo "Projeto       : $ROOT_DIR"
echo


# ============================================================
# ETAPA 1 — ATUALIZAR APT
# ============================================================

echo
echo "[1/9] Atualizando lista de pacotes..."
echo

apt-get update


# ============================================================
# ETAPA 2 — INSTALAR PROGRAMAS
# ============================================================
#
# make:
#   usado pelo Makefile do Inception.
#
# sudo:
#   permitirá posteriormente usar sudo normalmente.
#
# docker.io:
#   Docker fornecido pelos repositórios Debian.

echo
echo "[2/9] Instalando make, sudo e Docker..."
echo

apt-get install -y \
	make \
	sudo \
	docker.io


# ============================================================
# ETAPA 3 — INSTALAR DOCKER COMPOSE
# ============================================================
#
# Dependendo da versão/distribuição, o Compose pode
# estar disponível com nomes diferentes.
#
# Tentamos primeiro as versões modernas.

echo
echo "[3/9] Instalando Docker Compose..."
echo


if apt-cache show docker-compose-plugin >/dev/null 2>&1; then

	echo "Usando pacote: docker-compose-plugin"

	apt-get install -y docker-compose-plugin


elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then

	echo "Usando pacote: docker-compose-v2"

	apt-get install -y docker-compose-v2


else

	echo "Usando pacote: docker-compose"

	apt-get install -y docker-compose

fi


# ============================================================
# ETAPA 4 — CONFIGURAR SUDO
# ============================================================

echo
echo "[4/9] Configurando sudo para $TARGET_USER..."
echo


# Adiciona o usuário ao grupo sudo.
#
# -a = append
# -G = supplementary groups
#
# O -a é extremamente importante.
#
# Sem ele, poderíamos remover o usuário dos outros grupos.

usermod -aG sudo "$TARGET_USER"


# Também criamos uma configuração específica em:
#
#   /etc/sudoers.d/usuario
#
# Isso é melhor do que editar /etc/sudoers diretamente.

cat > "$SUDOERS_FILE" <<EOF
$TARGET_USER ALL=(ALL:ALL) ALL
EOF


# Arquivos sudoers precisam ter permissões restritas.

chmod 440 "$SUDOERS_FILE"


# visudo verifica se a sintaxe está correta.
#
# Se houver erro, abortamos imediatamente.

if ! visudo -cf "$SUDOERS_FILE" >/dev/null; then

	rm -f "$SUDOERS_FILE"

	die "Arquivo sudoers inválido."

fi


echo "Sudo configurado."


# ============================================================
# ETAPA 5 — CONFIGURAR DOCKER SEM SUDO
# ============================================================

echo
echo "[5/9] Configurando Docker para $TARGET_USER..."
echo


# Algumas instalações já criam o grupo docker.
#
# Se não existir, criamos.

if ! getent group docker >/dev/null; then

	groupadd docker

fi


# Adiciona o usuário ao grupo docker.
#
# Isso permitirá posteriormente:
#
#   docker ps
#
# em vez de:
#
#   sudo docker ps

usermod -aG docker "$TARGET_USER"


# Ativa o Docker automaticamente durante o boot.
#
# --now também inicia o serviço imediatamente.

systemctl enable --now docker


echo "Docker configurado."


# ============================================================
# ETAPA 6 — SUBSTITUIR LOGIN NO PROJETO
# ============================================================
#
# Procura recursivamente arquivos de texto contendo:
#
#   mviana
#
# ou:
#
#   mviana-v
#
# Exemplos:
#
#   mviana-v.42.fr
#        ↓
#   lalves-d.42.fr
#
#
#   /home/mviana/data
#        ↓
#   /home/lalves-d/data
#
#
# O diretório .git é ignorado.
#
# O próprio setup.sh também é ignorado.

echo
echo "[6/9] Substituindo login no projeto..."
echo


ALTERED_FILES=0


while IFS= read -r -d '' file; do

	# Faz a substituição global dentro do arquivo.

	sed -E -i \
		"s|$OLD_REGEX|$NEW_LOGIN|g" \
		"$file"


	# Como estamos executando como root,
	# garantimos que o arquivo continue pertencendo
	# ao usuário original.

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


echo
echo "Arquivos alterados: $ALTERED_FILES"


# ============================================================
# ETAPA 7 — CONFIGURAR /etc/hosts
# ============================================================
#
# Queremos:
#
#   127.0.0.1 login.42.fr
#
# Primeiro removemos uma eventual configuração anterior
# daquele domínio.
#
# Depois adicionamos a configuração correta.

echo
echo "[7/9] Configurando /etc/hosts..."
echo


HOSTS_TMP="$(mktemp)"


awk -v domain="$DOMAIN" '

{
	remove = 0

	for (i = 2; i <= NF; i++)
	{
		if ($i == domain)
		{
			remove = 1
			break
		}
	}

	if (!remove)
		print
}

END
{
	print "127.0.0.1\t" domain
}

' /etc/hosts > "$HOSTS_TMP"


# Substitui /etc/hosts pela versão atualizada.

cp "$HOSTS_TMP" /etc/hosts


# Remove arquivo temporário.

rm -f "$HOSTS_TMP"


echo "Adicionado:"
echo
echo "127.0.0.1	$DOMAIN"


# ============================================================
# ETAPA 8 — CRIAR .ENV
# ============================================================
#
# Copia:
#
#   env.example
#
# para:
#
#   srcs/.env

echo
echo "[8/9] Criando srcs/.env..."
echo


cp "$ENV_EXAMPLE" "$ENV_TARGET"


# Como a cópia foi feita por root,
# devolvemos o arquivo ao usuário.

chown "$TARGET_USER:$TARGET_GROUP" "$ENV_TARGET"


echo "Criado:"
echo
echo "  $ENV_TARGET"


# ============================================================
# ETAPA 9 — CRIAR DIRETÓRIOS DOS VOLUMES
# ============================================================
#
# Exemplo:
#
#   /home/lalves-d/data/
#   ├── mariadb
#   └── wordpress

echo
echo "[9/9] Criando diretórios dos volumes..."
echo


mkdir -p \
	"$DATA_DIR/mariadb" \
	"$DATA_DIR/wordpress"


# Os diretórios ficam pertencendo ao usuário da VM.

chown -R \
	"$TARGET_USER:$TARGET_GROUP" \
	"$DATA_DIR"


echo "$DATA_DIR/"
echo "├── mariadb"
echo "└── wordpress"


# ============================================================
#
#                VALIDAÇÃO FINAL
#
# ============================================================
#
# A partir daqui não configuramos mais nada.
#
# Apenas verificamos se tudo que fizemos realmente
# ficou funcionando.
#
# O reboot SÓ acontece se TODOS esses testes passarem.
# ============================================================


echo
echo "========================================="
echo " VALIDANDO CONFIGURAÇÃO"
echo "========================================="
echo


# ============================================================
# TESTE 1 — MAKE
# ============================================================

echo -n "[TESTE] make.................... "

if command -v make >/dev/null 2>&1; then

	echo "OK"

else

	echo "ERRO"
	die "make não está instalado."

fi


# ============================================================
# TESTE 2 — DOCKER
# ============================================================

echo -n "[TESTE] Docker.................. "

if command -v docker >/dev/null 2>&1; then

	echo "OK"

else

	echo "ERRO"
	die "Docker não está instalado."

fi


# ============================================================
# TESTE 3 — DOCKER COMPOSE
# ============================================================

echo -n "[TESTE] Docker Compose.......... "

if docker compose version >/dev/null 2>&1; then

	echo "OK"
	COMPOSE_COMMAND="docker compose"

elif command -v docker-compose >/dev/null 2>&1; then

	echo "OK"
	COMPOSE_COMMAND="docker-compose"

else

	echo "ERRO"
	die "Docker Compose não está disponível."

fi


# ============================================================
# TESTE 4 — SERVIÇO DOCKER
# ============================================================

echo -n "[TESTE] Docker daemon........... "

if systemctl is-active --quiet docker; then

	echo "OK"

else

	echo "ERRO"
	die "O serviço Docker não está ativo."

fi


# ============================================================
# TESTE 5 — GRUPO SUDO
# ============================================================

echo -n "[TESTE] Grupo sudo.............. "

if id -nG "$TARGET_USER" |
	tr ' ' '\n' |
	grep -qx "sudo"; then

	echo "OK"

else

	echo "ERRO"
	die "$TARGET_USER não está no grupo sudo."

fi


# ============================================================
# TESTE 6 — SUDOERS
# ============================================================

echo -n "[TESTE] sudoers................. "

if visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then

	echo "OK"

else

	echo "ERRO"
	die "Configuração sudoers inválida."

fi


# ============================================================
# TESTE 7 — GRUPO DOCKER
# ============================================================

echo -n "[TESTE] Grupo docker............ "

if id -nG "$TARGET_USER" |
	tr ' ' '\n' |
	grep -qx "docker"; then

	echo "OK"

else

	echo "ERRO"
	die "$TARGET_USER não está no grupo docker."

fi


# ============================================================
# TESTE 8 — DOCKER SEM SUDO
# ============================================================
#
# Esse teste é interessante:
#
# criamos uma NOVA sessão do usuário através de su.
#
# Essa nova sessão já recebe os grupos atualizados.
#
# Então conseguimos testar se:
#
#   docker info
#
# funciona realmente sem sudo.

echo -n "[TESTE] Docker sem sudo......... "

if su -s /bin/sh "$TARGET_USER" \
	-c "docker info >/dev/null 2>&1"; then

	echo "OK"

else

	echo "ERRO"
	die "O usuário ainda não consegue acessar Docker diretamente."

fi


# ============================================================
# TESTE 9 — /etc/hosts
# ============================================================

echo -n "[TESTE] /etc/hosts.............. "

if awk -v domain="$DOMAIN" '

$1 == "127.0.0.1"
{
	for (i = 2; i <= NF; i++)
	{
		if ($i == domain)
			found = 1
	}
}

END
{
	exit !found
}

' /etc/hosts; then

	echo "OK"

else

	echo "ERRO"
	die "$DOMAIN não está corretamente configurado."

fi


# ============================================================
# TESTE 10 — .ENV
# ============================================================

echo -n "[TESTE] srcs/.env............... "

if [ -f "$ENV_TARGET" ]; then

	echo "OK"

else

	echo "ERRO"
	die "srcs/.env não existe."

fi


# ============================================================
# TESTE 11 — CONTEÚDO DO .ENV
# ============================================================
#
# Confirma que a cópia realmente corresponde ao env.example.

echo -n "[TESTE] cópia do env.example.... "

if cmp -s "$ENV_EXAMPLE" "$ENV_TARGET"; then

	echo "OK"

else

	echo "ERRO"
	die "srcs/.env é diferente de env.example."

fi


# ============================================================
# TESTE 12 — DIRETÓRIO MARIADB
# ============================================================

echo -n "[TESTE] volume MariaDB.......... "

if [ -d "$DATA_DIR/mariadb" ]; then

	echo "OK"

else

	echo "ERRO"
	die "Diretório do MariaDB não foi criado."

fi


# ============================================================
# TESTE 13 — DIRETÓRIO WORDPRESS
# ============================================================

echo -n "[TESTE] volume WordPress........ "

if [ -d "$DATA_DIR/wordpress" ]; then

	echo "OK"

else

	echo "ERRO"
	die "Diretório do WordPress não foi criado."

fi


# ============================================================
# TESTE 14 — VERIFICAR SUBSTITUIÇÕES
# ============================================================
#
# Procuramos novamente:
#
#   mviana
#   mviana-v
#
# Se ainda existir alguma ocorrência dentro do projeto,
# consideramos a configuração incompleta.
#
# Novamente ignoramos:
#
#   .git
#   setup.sh

echo -n "[TESTE] login antigo............ "


if grep -rIl \
	--exclude-dir=".git" \
	--exclude="$SCRIPT_NAME" \
	-E "$OLD_REGEX" \
	"$ROOT_DIR" 2>/dev/null |
	grep -q .; then

	echo "ERRO"

	die "Ainda existem ocorrências de mviana/mviana-v."

else

	echo "OK"

fi


# ============================================================
# MOSTRAR VERSÕES INSTALADAS
# ============================================================

echo
echo "========================================="
echo " VERSÕES"
echo "========================================="
echo

make --version | head -n 1

docker --version

if [ "$COMPOSE_COMMAND" = "docker compose" ]; then

	docker compose version

else

	docker-compose --version

fi


# ============================================================
# RESULTADO FINAL
# ============================================================

echo
echo "========================================="
echo " TODOS OS TESTES PASSARAM"
echo "========================================="
echo
echo "Usuário:"
echo "  $TARGET_USER"
echo
echo "Login 42:"
echo "  $NEW_LOGIN"
echo
echo "Domínio:"
echo "  https://$DOMAIN"
echo
echo "Volumes:"
echo "  $DATA_DIR/mariadb"
echo "  $DATA_DIR/wordpress"
echo
echo ".env:"
echo "  $ENV_TARGET"
echo
echo "Grupos:"
id "$TARGET_USER"
echo
echo "Docker:"
echo "  usuário autorizado sem sudo"
echo
echo "Sudo:"
echo "  usuário autorizado"
echo


# ============================================================
# GARANTIR ESCRITA EM DISCO
# ============================================================
#
# sync força buffers pendentes a serem escritos em disco
# antes da reinicialização.

echo "Sincronizando dados com o disco..."

sync


# ============================================================
# REBOOT
# ============================================================
#
# Se chegamos até aqui:
#
#   - todos os comandos anteriores funcionaram;
#   - todos os testes passaram;
#   - Docker está funcionando;
#   - usuário está em sudo;
#   - usuário está em docker;
#   - sudoers está válido;
#   - domínio está configurado;
#   - .env existe;
#   - volumes existem;
#   - login antigo desapareceu.
#
# Portanto podemos reiniciar a máquina.

echo
echo "========================================="
echo " CONFIGURAÇÃO CONCLUÍDA COM SUCESSO"
echo "========================================="
echo
echo "A VM será reiniciada em 5 segundos."
echo

sleep 5


# systemctl reboot solicita ao systemd
# uma reinicialização organizada da máquina.

systemctl reboot
