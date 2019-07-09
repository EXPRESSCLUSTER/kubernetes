######################################## 
# Before you run this script please do the following steps
# - Modify /etc/hostsc file
# - Use static IP address
# - Disable swap
######################################## 

# Disable SELinux
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# Disable firewall
systemctl stop firewalld
systemctl disable firewalld

# Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Enable IPv4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

