# scripts de configuração automática do servidor vpn ipsec/l2tp

nota: esse repositório foi criado a partir dos trabalhos dos gists github:
- <a href="https://gist.github.com/hwdsl2/9030462/2aaaf443855de0275dad8a4e45bea523b5b0f966" target="_blank">gist.github.com/hwdsl2/9030462</a> *(237 estrelas, 92 forks)*
- <a href="https://gist.github.com/hwdsl2/e9a78a50e300d12ae195/5f68fb260c5c143e10d3cf6b3ce2c2f5426f7c1e" target="_blank">gist.github.com/hwdsl2/e9a78a50e300d12ae195</a> *(20 estrelas, 8 forks)*

scripts para configuração automática de um servidor vpn ipsec/l2tp no ubuntu 14.04 e 12.04, debian 8 e centos/rhel 6 e 7. tudo que você precisa fazer é fornecer seus próprios valores para `IPSEC_PSK`, `VPN_USER` e `VPN_PASSWORD`, e eles cuidarão do resto. esses scripts também podem ser usados ​​diretamente como "dados do usuário" do amazon ec2 ao criar uma nova instância.

utilizaremos <a href="https://libreswan.org/" target="_blank">libreswan</a> como o servidor ipsec, e <a href="https://www.xelerance.com/services/software/xl2tpd/" target="_blank">xl2tpd</a> como o fornecedor l2tp.

### <a href="https://blog.ls20.com/ipsec-l2tp-vpn-auto-setup-for-ubuntu-12-04-on-amazon-ec2/" target="_blank">meu tutorial de vpn com instruções detalhadas de uso</a>

## requisitos

uma instância do amazon ec2 recém-criada, usando estas amis: (veja o link acima para obter instruções de uso)

- <a href="http://cloud-images.ubuntu.com/trusty/current/" target="_blank">ubuntu 14.04 (confiável)</a> ou <a href="http://cloud-images.ubuntu.com/precise/current/" target="_blank">12.04 (preciso)</a>
- <a href="https://wiki.debian.org/Cloud/AmazonEC2Image/Jessie" target="_blank">imagens ec2 do debian 8 (jessie)</a>
- <a href="https://aws.amazon.com/marketplace/pp/B00O7WM7QW" target="_blank">centos 7 (x86_64) com atualizações hvm</a>
- <a href="https://aws.amazon.com/marketplace/pp/B00NQAYLWO" target="_blank">centos 6 (x86_64) com atualizações hvm</a> - não possui inicialização em nuvem. execute o script manualmente após a criação.

**ou**

um servidor dedicado ou qualquer servidor virtual privado (vps) baseado em kvm ou xen, com **recém-instalado**:
- ubuntu 14.04 (confiável) ou 12.04 (preciso)
- debian 8 (jessie)
- debian 7 (wheezy) - é necessária uma solução alternativa. veja abaixo.
- centos / red hat enterprise linux (rhel) 6 ou 7

os usuários do openvz vps devem usar <a href="https://github.com/Nyr/openvpn-install" target="_blank">script openvpn de nyr</a>.

##### Note: Do NOT run these scripts on your PC or Mac! They are meant to be run on a dedicated server or VPS!

## instalação

### para ubuntu e debian:

```bash
wget https://github.com/hwdsl2/setup-ipsec-vpn/raw/master/vpnsetup.sh -O vpnsetup.sh
nano -w vpnsetup.sh
[edite e substitua ipsec_psk, vpn_user e vpn_password pelos seus próprios valores]
/bin/sh vpnsetup.sh
```

solução alternativa necessária somente para o debian 7 (wheezy): (execute estes comandos primeiro)

```bash
wget https://gist.github.com/hwdsl2/5a769b2c4436cdf02a90/raw -O vpnsetup-workaround.sh
/bin/sh vpnsetup-workaround.sh
```

### para centos e rhel:

```bash
yum -y install wget nano
wget https://github.com/hwdsl2/setup-ipsec-vpn/raw/master/vpnsetup_centos.sh -O vpnsetup_centos.sh
nano -w vpnsetup_centos.sh
[edite e substitua ipsec_psk, vpn_user e vpn_password pelos seus próprios valores]
/bin/sh vpnsetup_centos.sh
```

## atualizando o libreswan

você pode usar os scripts `vpnupgrade_Libreswan.sh` (para o ubuntu/debian) e `vpnupgrade_Libreswan_centos.sh` (para o centos/rhel) para atualizar o <a href="https://libreswan.org/" target="_blank">libreswan</a> para uma versão mais recente.

## notas importantes

aprenda como <a href="https://gist.github.com/hwdsl2/123b886f29f4c689f531" target="_blank">habilitar vários usuários vpn</a> com diferentes credenciais.

para usuários windows, uma <a href="https://documentation.meraki.com/MX-Z/Client_VPN/Troubleshooting_Client_VPN#Windows_Error_809" target="_blank">alteração única de registro</a> é necessária para conexões com um servidor vpn atrás da nat (por exemplo, o amazon ec2).

se estiver usando o amazon ec2, essas portas deverão estar abertas no grupo de segurança do seu servidor vpn: portas udp 500 e 4500 e porta tcp 22 (opcional, para ssh).

se o seu servidor usa uma porta ssh personalizada (não a 22), ou se você deseja permitir outros serviços através do iptables, certifique-se de editar as regras do iptables nos scripts antes de usar.

os scripts farão backup de /etc/rc.local, /etc/sysctl.conf, /etc/iptables.rules e /etc/sysconfig/iptables antes de substituí-los. os backups podem ser encontrados na mesma pasta com o sufixo .old.

## copyright e licença

copyright (c) 2024&nbsp;cavassani&nbsp;&nbsp;&nbsp;<a href="https://www.linkedin.com/in/cavassani" target="_blank"><img src="https://static.licdn.com/scds/common/u/img/webpromo/btn_profile_bluetxt_80x15.png" width="80" height="15" border="0" alt="veja meu perfil no linkedin"></a>
baseado no <a href="https://github.com/sarfata/voodooprivacy" target="_blank">trabalho de thomas sarlandie</a> (copyright 2012)

esse trabalho está sob a licença da <a href="http://creativecommons.org/licenses/by-sa/3.0/" target="_blank">creative commons attribution-sharealike 3.0</a>
