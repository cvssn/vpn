## script de auto-instalação de vpn ipsec/l2tp para ubuntu/debian

nota: esse repositório foi criado a partir desses gists do github:
- https://gist.github.com/hwdsl2/9030462 (237 estrelas, 92 forks)
- https://gist.github.com/hwdsl2/e9a78a50e300d12ae195 (20 estrelas, 8 forks)

arquivo de dados do usuário do amazon ec2 para configuração automática do servidor vpn ipsec/l2tp em uma instância ubuntu ou debian. testado com cbuntu 14.04 e 12.04 debian 8 (jessie).

com pequenas modificações, este script **também pode ser usado** em servidores dedicados ou qualquer servidor virtual privado (vps) baseado em kvm ou xen de outros provedores.

#### <a href="https://blog.ls20.com/ipsec-l2tp-vpn-auto-setup-for-ubuntu-12-04-on-amazon-ec2/" target="_blank">meu tutorial de vpn com instruções detalhadas de uso</a>
<a href="https://gist.github.com/hwdsl2/e9a78a50e300d12ae195" target="_blank">script de vpn alternativo para centos/rhel</a>  
<a href="https://gist.github.com/hwdsl2/5a769b2c4436cdf02a90" target="_blank">solução alternativa para o debian 7</a>  
<a href="http://www.sarfata.org/posts/setting-up-an-amazon-vpn-server.md" target="_blank">post original de thomas sarlandie</a>

&darr;&nbsp;&nbsp;&darr;&nbsp;&nbsp;&darr; role para baixo para ver o script &darr;&nbsp;&nbsp;&darr;&nbsp;&nbsp;&darr;

### copyright e licença

copyright (c) 2024&nbsp;cavassani&nbsp;&nbsp;&nbsp;<a href="https://www.linkedin.com/in/cavassani" target="_blank"><img src="https://static.licdn.com/scds/common/u/img/webpromo/btn_profile_bluetxt_80x15.png" width="80" height="15" border="0" alt="veja meu perfil no linkedin"></a>
baseado no trabalho de thomas sarlandie (copyright 2012)

esse trabalho está sob a licença da <a href="http://creativecommons.org/licenses/by-sa/3.0/" target="_blank">creative commons attribution-sharealike 3.0</a>
