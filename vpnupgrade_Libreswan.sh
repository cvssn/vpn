#!/bin/sh
#
# script simples para atualizar o libreswan no ubuntu e debian
#
# copyright (c) 2024 cavassani
#
# esse trabalho está licenciado sob creative commons attribution-sharealike 3.0
# https://creativecommons.org/licenses/by-sa/3.0/

SWAN_VER=3.16

if [ "$(lsb_release -si)" != "Ubuntu" ] && [ "$(lsb_release -si)" != "Debian" ]; then
    echo "parece que você não está executando este script em um sistema ubuntu ou debian."

    exit 1
fi

if [ "$(sed 's/\..*//' /etc/debian_version 2>/dev/null)" = "7" ]; then
    echo "desculpe, este script não suporta o debian 7 (wheezy)."

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

# atualizar o pacote index e instalar o wget e nano
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install wget nano

# instalar os pacotes necessários
apt-get -y install libnss3-dev libnspr4-dev pkg-config libpam0g-dev \
        libcap-ng-dev libcap-ng-utils libselinux1-dev \
        libcurl4-nss-dev libgmp3-dev flex bison gcc make \
        libunbound-dev libnss3-tools libevent-dev
apt-get -y --no-install-recommends install xmlto
apt-get -y install xl2tpd

# compilar e instalar libreswan (https://libreswan.org/)
SWAN_URL=https://download.libreswan.org/libreswan-${SWAN_VER}.tar.gz
/bin/rm -rf "/opt/src/libreswan-${SWAN_VER}"
wget -t 3 -T 30 -qO- $SWAN_URL | tar xvz
[ ! -d libreswan-${SWAN_VER} ] && { echo "não foi possível recuperar os arquivos de origem do libreswan. abortando."; exit 1; }
cd libreswan-${SWAN_VER}
make programs && make install

ipsec --version 2>/dev/null | grep -qs "Libreswan ${SWAN_VER}"
if [ "$?" != "0" ]; then
    echo
    echo "desculpe, algo deu errado."
    echo "libreswan ${SWAN_VER} não foi instalado com sucesso."
    echo "deixando o script."

    exit 1
fi

service ipsec restart
service xl2tpd restart

echo
echo "parabéns! o libreswan ${SWAN_VER} foi instalado com sucesso."

exit 0