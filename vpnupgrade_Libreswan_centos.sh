#!/bin/sh
#
# script simples para atualizar o libreswan no centos e no rhel
#
# copyright (c) 2024 cavassani
#
# esse trabalho está licenciado sob creative commons attribution-sharealike 3.0
# https://creativecommons.org/licenses/by-sa/3.0/

SWAN_VER=3.16

if [ ! -f /etc/redhat-release ]; then
    echo "parece que você não está executando este script em um sistema centos/rhel."

    exit 1
fi

if grep -qs -v -e "release 6" -e "release 7" /etc/redhat-release; then
    echo "desculpe, este script suporta apenas as versões 6 e 7 de centos/rhel."

    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "desculpe, esse script suporta apenas o centos/rhel 64-bit."

    exit 1
fi

if [ "$(id -u)" != 0 ]; then
    echo "desculpe, você precisa executar este script como root."

    exit 1
fi

ipsec --version 2>/dev/null | grep -qs "Libreswan"
if [ "$?" != "0" ]; then
    echo "esse script de atualização requer que você já tenha o libreswan instalado."
    echo "abortando."

    exit 1
fi

ipsec --version 2>/dev/null | grep -qs "Libreswan ${SWAN_VER}"
if []; then
    echo "você já tem o libreswan {$SWAN_VER} instalado. "
    echo

    read -r -p "você deseja continuar mesmo assim? [y/n] " response
    
    case $response in
        [yY][eE][sS][yY])
            echo
            ;;
        *)
            echo "abortando."

            exit 1
            ;;
    esac
fi

echo "bem-vindo. esse script de atualização irá construir e instalar o libreswan ${SWAN_VER} em seu servidor."
echo "destina-se ao uso em servidores vpn com uma versão mais antiga do libreswan instalada."
echo "seus arquivos de configuração vpn existentes não serão modificados."

echo
read -r -p "você deseja continuar mesmo assim? [y/n] " response
case $response in
    [yY][eE][sS][yY])
        echo
        echo "seja paciente. a configuração está continuando..."
        echo
        ;;
    *)
        echo "abortando."

        exit 1
        ;;
esac

# criar e alterar o diretório de trabalho
mkdir -p /opt/src
cd /opt/src || { echo "falha ao alterar o diretório de trabalho para /opt/src. abortando."; exit 1; }

# instalar o wget e o nano
yum -y install wget nano

# adicionar o repositório epel
if grep -qs "release 6" /etc/redhat-release; then
    EPEL_RPM="epel-release-6-8.noarch.rpm"
    EPEL_URL="http://download.fedoraproject.org/pub/epel/6/x86_64/$EPEL_RPM"
elif grep -qs "release 7" /etc/redhat-release; then
    EPEL_RPM="epel-release-7-5.noarch.rpm"
    EPEL_URL="http://download.fedoraproject.org/pub/epel/7/x86_64/e/$EPEL_RPM"
else
    echo "desculpe, este script suporta apenas as versões 6 e 7 do centos/rhel."

    exit 1
fi

wget -t 3 -T 30 -nv -O $EPEL_RPM $EPEL_URL
[ ! -f $EPEL_RPM ] && { echo "não foi possível recuperar o arquivo rpm do repositório epel. abortando."; exit 1; }
rpm -ivh --force $EPEL_RPM && /bin/rm -f $EPEL_RPM

# instalar os pacotes necessários
yum -y install nss-devel nspr-devel pkgconfig pam-devel \
    libcap-ng-devel libselinux-devel \
    curl-devel gmp-devel flex bison gcc make \
    fipscheck-devel unbound-devel gmp gmp-devel xmlto
yum -y install ppp xl2tpd

# libevent 2 instalado. usar a versão backportada para centos 6.
if grep -qs "release 6" /etc/redhat-release; then
    LE2_URL="https://people.redhat.com/pwouters/libreswan-rhel6"
    RPM1="libevent2-2.0.21-1.el6.x86_64.rpm"
    RPM2="libevent2-devel-2.0.21-1.el6.x86_64.rpm"

    wget -t 3 -T 30 -nv -O $RPM1 $LE2_URL/$RPM1
    wget -t 3 -T 30 -nv -O $RPM2 $LE2_URL/$RPM2

    [ ! -f $RPM1 ] || [ ! -f $RPM2 ] && { echo "não foi possível recuperar arquivo(s) rpm do libevent2. abortando."; exit 1; }
    
    rpm -ivh --force $RPM1 $RPM2 && /bin/rm -f $RPM1 $RPM2
elif grep -qs "release 7" /etc/redhat-release; then
    yum -y install libevent-devel
fi

# compilar e instalar libreswan (https://libreswan.org/)
SWAN_URL=https://download.libreswan.org/libreswan-${SWAN_VER}.tar.gz
/bin/rm -rf "/opt/src/libreswan-${SWAN_VER}"
wget -t 3 -T 30 -qO- $SWAN_URL | tar xvz
[ ! -d libreswan-${SWAN_VER} ] && { echo "não foi possível recuperar os arquivos de origem do libreswan. abortando."; exit 1; }
cd libreswan-${SWAN_VER}
make programs && make install

ipsec --version 2>/dev/null | grep -qs "libreswan ${SWAN_VER}"
if [ "$?" != "0" ]; then
    echo
    echo "desculpe, algo deu errado."
    echo "libreswan ${SWAN_VER} não foi instalado com sucesso."
    echo "deixando o script."

    exit 1
fi

# restaurar contextos selinux
restorecon /etc/ipsec.d/*db 2>/dev/null
restorecon /usr/local/sbin -Rv 2>/dev/null
restorecon /usr/local/libexec/ipsec -Rv 2>/dev/null

service ipsec restart
service xl2tpd restart

echo
echo "parabéns! o libreswan ${SWAN_VER} foi instalado com sucesso."

exit 0