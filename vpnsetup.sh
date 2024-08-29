#!/bin/sh
#
# arquivo de dados do usuário do amazon ec2 para configuração automática de vpn ipsec/l2tp
# em uma instância de servidor ubuntu ou debian. testado com ubuntu 14.04 e 12.04 e debian 8 e 7.
# com pequenas modificações, este script também pode ser usado em servidores dedicados
# ou qualquer servidor virtual privado (vps) baseado em kvm ou xen de outros provedores.
#
# NÃO EXECUTE ESTE SCRIPT NO SEU PC OU MAC! ISTO DEVE SER EXECUTADO QUANDO SUA INSTÂNCIA
# DO AMAZON EC2 INICIAR
#
# para instruções mais detalhadas, por favor veja:
# https://blog.ls20.com/ipsec-l2tp-vpn-auto-setup-for-ubuntu-12-04-on-amazon-ec2/
#
# versão centos/rhel:
# https://gist.github.com/hwdsl2/e9a78a50e300d12ae195
#
# post original por thomas sarlandie:
# https://www.sarfata.org/posts/setting-up-an-amazon-vpn-server.md/
#
# copyright (c) 2024 cavassani
# baseado no trabalho de thomas sarlandie (copyright 2012)
#
# esse trabalho é licensiado a partir da licença creative commons attribution-sharealike 3.0
# licença: https://creativecommons.org/licenses/by-sa/3.0/

if [ "$(uname)" = "Darwin" ]; then
    echo 'não rode esse script no seu mac. ele deve ser apenas rodado em uma instância recente ec2'
    echo 'ou outro servidor dedicado/vps, depois de modificado e com as variáveis configuradas.'
    echo 'por favor veja as instruções detalhadas nos urls dos comentários.'

    exit
fi

if [ "$(lsb_release -si)" != "Ubuntu" ] && [ "$(lsb_release -si)" != "Debian" ]; then
    echo "parece que você não está rodando esse script em um sistema ubuntu ou debian."

    exit
fi

if [ "$(id -u)" != 0 ]; then
    echo 'desculpe, você precisa rodar esse script como root.'

    exit
fi

# por favor defina seus valores para essas variáveis
IPSEC_KEY=sua_key_segura
VPN_USER=seu_username
VPN_PASSWORD=sua_senha_segura

# se você precisar de múltiplos usuários vpn com diferentes credenciais,
# veja: https://gist.github.com/hwdsl2/123b886f29f4c689f531

# notas importantes:
# para usuários windows, uma mudança de registro é necessária para permitir
# as conexões a um servidor vpn por meio da nat. refere-se a sessão "erro 809"
# nessa página:
# https://kb.meraki.com/knowledge_base/troubleshooting-client-vpn

# usuários de iphone/ios talvez precisem substituir essa linha em ipsec.conf:
# "rightprotoport=17/%any" por "rightprotoport=17/0"

# caso esteja usando o amazon ec2, esses portos devem ser abertos em um grupo
# segurança do seu servidor vpn: portos udp 500 & 4500, e porto tcp 22 (opcional, para ssh)

# atualizar o índice do pacote e instalar o wget, dig (dnsutils) e nano
apt-get -y update
apt-get -y install wget dnsutils nano

echo 'se o script travar aqui, pressione ctrl-c para interromper, edite-o e comente'
echo 'as próximas duas linhas PUBLIC_IP= e PRIVATE_IP=, ou substitua-as pelos ips reais.'

# no amazon ec2, essas duas variáveis serão encontradas automaticamente pelos
# outros servidores, você talvez precise substituir com o ip atual, ou
# comentar e deixar o script auto-detectar a próxima sessão
#
# se o seu servidor apenas possui um ip público, utilize esse ip em ambas as linhas
PUBLIC_IP=$(wget --timeout 10 -q -O - 'http://169.254.169.254/latest/meta-data/public-ipv4')
PRIVATE_IP=$(wget --timeout 10 -q -O - 'http://169.254.169.254/latest/meta-data/local-ipv4')

# tentativa de encontrar o ip público e ip privado automaticamente para servidores não ec2
[ "$PUBLIC_IP" = "" ] && PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
[ "$PUBLIC_IP" = "" ] && { echo "não foi possível encontrar o ip público. edite o script manualmente."; exit; }

[ "$PRIVATE_IP" = "" ] && PRIVATE_IP=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
[ "$PRIVATE_IP" = "" ] && { echo "não foi possível encontrar o ip privado. edite o script manualmente."; exit; }

# instale os pacotes necessários
apt-get -y install libnss3-dev libnspr4-dev pkg-config libpam0g-dev \
        libcap-ng-dev libcap-ng-utils libselinux1-dev \
        libcurl4-nss-dev libgmp3-dev flex bison gcc make \
        libunbound-dev libnss3-tools
apt-get -y install xl2tpd

# compilar e instalar o libreswan (https://libreswan.org/)
#
# para atualizar o libreswan quando uma versão mais recente estiver disponível, basta
# executar novamente estes seis comandos com o novo link de download e, em seguida
# reiniciar os serviços com "service ipsec restart" e "service xl2tpd restart"
mkdir -p /opt/src
cd /opt/src
wget -qO- https://download.libreswan.org/libreswan-3.13.tar.gz | tar xvz
cd libreswan-3.13
make programs
make install

# preparar os arquivos de configuração
cat > /etc/ipsec.conf <<EOF
version 2.0

config setup
    dumpdir=/var/run/pluto/
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!192.168.42.0/24
    oe=off
    protostack=netkey
    nhelpers=0
    interfaces=%defaultroute

conn vpnpsk
    connaddrfamily=ipv4
    auto=add
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=$PRIVATE_IP/32
    leftnexthop=%defaultroute
    leftprotoport=17/1701
    rightprotoport=17/%any
    right=%any
    rightsubnetwithin=0.0.0.0/0
    forceencaps=yes
    authby=secret
    pfs=no
    type=transport
    auth=esp
    ike=3des-sha1,aes-sha1
    phase2alg=3des-sha1,aes-sha1
    rekey=no
    keyingtries=5
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
EOF

cat > /etc/ipsec.secrets <<EOF
$PUBLIC_IP %any : PSK "$IPSEC_PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

;debug avp = yes
;debug network = yes
;debug state = yes
;debug tunnel = yes

[lns padrão]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
crtscts
idle 1800
mtu 1280
mru 1280
lock
lcp-echo-failure 10
lcp-echo-interval 60
connect-delay 5000
EOF

cat > /etc/ppp/chap-secrets <<EOF
# segredos para autenticação utilizando o cliente
# chap para endereços de ip secretos

$VPN_USER l2tpd $VPN_PASSWORD *
EOF

/bin/cp -f /etc/sysctl.conf /etc/sysctl.conf.old-$(date +%Y-%m-%d-%H:%M:%S) 2>/dev/null
cat > /etc/sysctl.conf <<EOF
kernel.sysrq = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
kernel.randomize_va_space = 1
net.core.wmem_max=12582912
net.core.rmem_max=12582912
net.ipv4.tcp_rmem= 10240 87380 12582912
net.ipv4.tcp_wmem= 10240 87380 12582912
EOF

/bin/cp -f /etc/iptables.rules /etc/iptables.rules.old-$(date +%Y-%m-%d-%H:%M:%S) 2>/dev/null
cat > /etc/iptables.rules <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:ICMPALL - [0:0]
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type 255 -j ICMPALL
-A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p udp -m multiport --dports 500,4500 -j ACCEPT
-A INPUT -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT
-A INPUT -p udp --dport 1701 -j DROP
-A INPUT -j DROP
-A FORWARD -m conntrack --ctstate INVALID -j DROP
-A FORWARD -i eth+ -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ppp+ -o eth+ -j ACCEPT
-A FORWARD -j DROP
-A ICMPALL -p icmp -f -j DROP
-A ICMPALL -p icmp --icmp-type 0 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 3 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 4 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 8 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 11 -j ACCEPT
-A ICMPALL -p icmp -j DROP
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.42.0/24 -o eth+ -j SNAT --to-source ${PRIVATE_IP}
COMMIT
EOF

cat > /etc/network/if-pre-up.d/iptablesload <<EOF
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
exit 0
EOF

/bin/cp -f /etc/rc.local /etc/rc.local.old-$(date +%Y-%m-%d-%H:%M:%S) 2>/dev/null
cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# esse script é executado no final de cada runlevel de multiusuário.
# certifique-se de que o script irá rodar "exit 0" no sucesso de
# qualquer outro valor durante o erro.
#
# para ativar ou desativar este script basta alterar os bits de
# execução.
#
# por padrão, este script não faz nada.
/usr/sbin/service ipsec restart
/usr/sbin/service xl2tpd restart
echo 1 > /proc/sys/net/ipv4/ip_forward
exit 0
EOF

if [ ! -f /etc/ipsec.d/cert8.db ] ; then
   echo > /var/tmp/libreswan-nss-pwd
   /usr/bin/certutil -N -f /var/tmp/libreswan-nss-pwd -d /etc/ipsec.d
   /bin/rm -f /var/tmp/libreswan-nss-pwd
fi

/sbin/sysctl -p
/bin/chmod +x /etc/network/if-pre-up.d/iptablesload
/bin/chmod 600 /etc/ipsec.secrets /etc/ppp/chap-secrets
/sbin/iptables-restore < /etc/iptables.rules

/usr/sbin/service ipsec restart
/usr/sbin/service xl2tpd restart