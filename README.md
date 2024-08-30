# scripts de configuração automática do servidor vpn ipsec/l2tp

nota: esse repositório foi criado a partir dos trabalhos dos gists github:
- https://gist.github.com/hwdsl2/9030462 (237 estrelas, 92 forks)
- https://gist.github.com/hwdsl2/e9a78a50e300d12ae195 (20 estrelas, 8 forks)

scripts para configuração automática de um servidor vpn ipsec/l2tp no ubuntu 14.04 e 12.04, debian 8 e centos/rhel 6 e 7. funciona em servidores dedicados ou qualquer servidor virtual privado (vps) baseado em kvm ou xen, com linux recém-instalado os.

eles também podem ser usados ​​como "dados do usuário" do amazon ec2 com o <a href="https://cloud-images.ubuntu.com/locator/ec2/" target="_blank">ubuntu 14.04/12.04</a>, <a href="https://wiki.debian.org/Cloud/AmazonEC2Image/Jessie" target="_blank">debian 8</a> ou <a href="https://aws.amazon.com/marketplace/pp/B00O7WM7QW" target="_blank">centos 7</a> amis.

*não* rodar esses scripts no pc ou mac. eles devem ser executados em um servidor dedicado ou vps.

#### <a href="https://blog.ls20.com/ipsec-l2tp-vpn-auto-setup-for-ubuntu-12-04-on-amazon-ec2/" target="_blank">meu tutorial de vpn com instruções detalhadas de uso</a>
<a href="https://gist.github.com/hwdsl2/123b886f29f4c689f531" target="_blank">habilitar múltiplos usuários vpn com diferentes credenciais</a>
<a href="https://gist.github.com/hwdsl2/5a769b2c4436cdf02a90" target="_blank">solução alternativa para o debian 7</a>
<a href="http://www.sarfata.org/posts/setting-up-an-amazon-vpn-server.md" target="_blank">post original de thomas sarlandie</a>

## instalação

### para ubuntu e debian:

```bash
wget https://github.com/hwdsl2/setup-ipsec-vpn/raw/master/vpnsetup.sh -O vpnsetup.sh
nano -w vpnsetup.sh
[edite e substitua ipsec_psk, vpn_user e vpn_password pelos seus próprios valores]
/bin/sh vpnsetup.sh
```

### para centos e rhel:

```bash
wget https://github.com/hwdsl2/setup-ipsec-vpn/raw/master/vpnsetup_centos.sh -O vpnsetup_centos.sh
nano -w vpnsetup_centos.sh
[edite e substitua ipsec_psk, vpn_user e vpn_password pelos seus próprios valores]
/bin/sh vpnsetup_centos.sh
```

## notas importantes

para usuários windows, uma <a href="https://documentation.meraki.com/MX-Z/Client_VPN/Troubleshooting_Client_VPN#Windows_Error_809" target="_blank">alteração única de registro</a> é necessária para conexões com um servidor vpn atrás da nat (por exemplo, o amazon ec2).

se estiver usando o amazon ec2, essas portas deverão estar abertas no grupo de segurança do seu servidor vpn: portas udp 500 e 4500 e porta tcp 22 (opcional, para ssh).

se o seu servidor usa uma porta ssh personalizada (não a 22), ou se você deseja permitir outros serviços através do iptables, certifique-se de editar as regras do iptables nos scripts antes de usar.

os scripts farão backup de /etc/rc.local, /etc/sysctl.conf, /etc/iptables.rules e /etc/sysconfig/iptables antes de substituí-los. os backups podem ser encontrados na mesma pasta com o sufixo .old.

## copyright e licença

copyright (c) 2024&nbsp;cavassani&nbsp;&nbsp;&nbsp;<a href="https://www.linkedin.com/in/cavassani" target="_blank"><img src="https://static.licdn.com/scds/common/u/img/webpromo/btn_profile_bluetxt_80x15.png" width="80" height="15" border="0" alt="veja meu perfil no linkedin"></a>
baseado no trabalho de thomas sarlandie (copyright 2012)

esse trabalho está sob a licença da <a href="http://creativecommons.org/licenses/by-sa/3.0/" target="_blank">creative commons attribution-sharealike 3.0</a>
