#!/bin/sh
#
# script para configuração automática do servidor vpn ipsec/l2tp em centos/rhel 6 e 7 de 64 bits.
# funciona em servidores dedicados ou em qualquer servidor virtual privado (vps) baseado em kvm ou xen.
# ele também pode ser usado como "dados do usuário" do amazon ec2 com a ami oficial do centos 7.
# observe que o centos 6 ami não vem com cloud-init, portanto, você precisa executar este script
# manualmente após a criação da instância.
#
# NÃO EXECUTAR O SCRIPT NO SEU PC OU MAC! ISTO DEVE SER EXECUTADO QUANDO SUA INSTÂNCIA
# DO AMAZON EC2 INICIAR
#
# copyright (c) 2024 cavassani
# baseado no trabalho de thomas sarlandie (copyright 2012)
#
# esse trabalho é licensiado a partir da licença creative commons attribution-sharealike 3.0
# licença: https://creativecommons.org/licenses/by-sa/3.0/

if [ "$(uname)" = "Darwin" ]; then
    echo 'não executar esse script no seu mac, só deve ser executado em um servidor sedicado/vps'
    echo 'ou em uma instância ec2 recém-criada, depois de modificá-la para definir as variáveis abaixo.'
    
    exit 1
fi

if [ ! -f /etc/redhat-release ]; then
    echo "parece que você não está executando este script em um sistema centos/rhel."
    
    exit 1
fi

if grep -qs -v -e "release 6" -e "release 7" /etc/redhat-release; then
    echo "desculpe, esse script suporta apenas as versões 6 e 7 do centos/rhel."
    
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "desculpe, este script suporta apenas centos/rhel de 64 bits."
    
    exit 1
fi

if [ "$(id -u)" != 0 ]; then
    echo "desculpe, você precisa executar este script como root."
  
    exit 1
fi

# defina seus próprios valores para essas variáveis
IPSEC_PSK=sua_key_segura
VPN_USER=seu_username
VPN_PASSWORD=sua_senha_segura

# NOTAS IMPORTANTES:

# se você precisar de vários usuários VPN com credenciais diferentes,
# veja: https://gist.github.com/hwdsl2/123b886f29f4c689f531

# para usuários do windows, é necessária uma alteração única no registro para
# conecte-se a um servidor vpn atrás de nat (por exemplo, no amazon ec2).
# por favor veja:
# https://documentation.meraki.com/MX-Z/Client_VPN/Troubleshooting_Client_VPN#Windows_Error_809

# caso esteja usando o amazon ec2, esses portos devem ser abertos em um grupo
# segurança do seu servidor vpn: portos udp 500 & 4500, e porto tcp 22 (opcional, para ssh)

# se o seu servidor usa uma porta ssh personalizada (não a 22) ou se você deseja permitir
# outros serviços por meio do iptables, certifique-se de editar as regras do iptables
# abaixo antes de executar este script.

# este script fará backup de /etc/rc.local, /etc/sysctl.conf e /etc/iptables.rules
# antes de sobrescrevê-los. os backups podem ser encontrados na mesma pasta com o sufixo .old.

# usuários de iphone/ios podem precisar substituir esta linha em ipsec.conf:
# "rightprotoport=17/%any" por "rightprotoport=17/0".

# criar e alterar o diretório de trabalho
mkdir -p /opt/src
cd /opt/src || { echo "falha ao alterar o diretório de trabalho para /opt/src. abortando."; exit 1; }

# Install wget, dig (bind-utils) and nano
yum -y install wget bind-utils nano

echo
echo 'aguarde... tentando encontrar o ip público e o ip privado deste servidor.'
echo
echo 'se o script travar aqui por mais de alguns minutos, pressione ctrl-c para interromper,'
echo 'em seguida, edite-o e comente as próximas duas linhas PUBLIC_IP= e PRIVATE_IP=,'
echo 'ou substitua-os pelos ips reais. se o seu servidor tiver apenas um ip público,'
echo 'coloque esse ip público em ambas as linhas.'
echo

# no amazon ec2, essas duas variáveis serão encontradas automaticamente.
# para todos os outros servidores, você talvez precise substituir com o
# ip atual, ou comentar e deixar o script auto-detectar a próxima sessão
#
# se o seu servidor apenas possui um ip público, ponha esse ip público em ambas as linhas
PUBLIC_IP=$(wget --retry-connrefused -t 3 -T 15 -qO- 'http://169.254.169.254/latest/meta-data/public-ipv4')
PRIVATE_IP=$(wget --retry-connrefused -t 3 -T 15 -qO- 'http://169.254.169.254/latest/meta-data/local-ipv4')

# tentativa de encontrar o ip do servidor automaticamente para servidores não ec2
[ "$PUBLIC_IP" = "" ] && PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
[ "$PUBLIC_IP" = "" ] && PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipecho.net/plain)
[ "$PUBLIC_IP" = "" ] && { echo "Could not find Public IP, please edit the VPN script manually."; exit 1; }
[ "$PRIVATE_IP" = "" ] && PRIVATE_IP=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
[ "$PRIVATE_IP" = "" ] && { echo "Could not find Private IP, please edit the VPN script manually."; exit 1; }

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

# instale os pacotes necessários
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

# compilar e instalar o libreswan (https://libreswan.org/)
#
# para atualizar o libreswan quando uma versão mais recente estiver disponível
# basta executar novamente estes comandos com o novo link de download e, em
# seguida reiniciar os serviços com "service ipsec restart" e "service xl2tpd
# restart"
SWAN_VER=3.16
SWAN_URL=https://download.libreswan.org/libreswan-${SWAN_VER}.tar.gz
wget -t 3 -T 30 -qO- $SWAN_URL | tar xvz
[ ! -d libreswan-${SWAN_VER} ] && { echo "não foi possível recuperar os arquivos de origem do libreswan. abortando"; exit 1; }
cd libreswan-${SWAN_VER}
make programs && make install

# preparar vários arquivos de configuração
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
[lns default]
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
# segredos para autenticação usando
# endereços ip secretos do servidor
# cliente chap
$VPN_USER l2tpd $VPN_PASSWORD *
EOF

/bin/cp -f /etc/sysctl.conf "/etc/sysctl.conf.old-$(date +%Y-%m-%d-%H:%M:%S)" 2>/dev/null
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

/bin/cp -f /etc/sysconfig/iptables "/etc/sysconfig/iptables.old-$(date +%Y-%m-%d-%H:%M:%S)" 2>/dev/null
cat > /etc/sysconfig/iptables <<EOF
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
# If you wish to allow traffic between VPN clients themselves, uncomment this line:
# -A FORWARD -i ppp+ -o ppp+ -s 192.168.42.0/24 -d 192.168.42.0/24 -j ACCEPT
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
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.42.0/24 -o eth+ -j SNAT --to-source ${PRIVATE_IP}
COMMIT
EOF

/bin/cp -f /etc/rc.local "/etc/rc.local.old-$(date +%Y-%m-%d-%H:%M:%S)" 2>/dev/null
cat > /etc/rc.local <<EOF
#!/bin/sh
#
# esse script será executado depois de todos os outros scripts
# de inicialização. você pode colocar seu próprio material de
# inicialização aqui se não quiser fazer o material de
# inicialização completo no estilo sys v.
touch /var/lock/subsys/local
/sbin/iptables-restore < /etc/sysconfig/iptables
/sbin/service ipsec restart
/sbin/service xl2tpd restart
echo 1 > /proc/sys/net/ipv4/ip_forward
EOF

if [ ! -f /etc/ipsec.d/cert8.db ] ; then
    echo > /var/tmp/libreswan-nss-pwd
    /usr/bin/certutil -N -f /var/tmp/libreswan-nss-pwd -d /etc/ipsec.d
    /bin/rm -f /var/tmp/libreswan-nss-pwd
fi

# restaurar contextos SELinux
restorecon /etc/ipsec.d/*db 2>/dev/null
restorecon /usr/local/sbin -Rv 2>/dev/null
restorecon /usr/local/libexec/ipsec -Rv 2>/dev/null

/sbin/sysctl -p
/bin/chmod 600 /etc/ipsec.secrets /etc/ppp/chap-secrets
/sbin/iptables-restore < /etc/sysconfig/iptables

/sbin/service ipsec restart
/sbin/service xl2tpd restart