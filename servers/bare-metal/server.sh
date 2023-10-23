# expose kubectl svc with iptable
sudo iptables -t nat -A PREROUTING -p tcp --dport 32174 -j DNAT --to 10.108.36.208:32174

# IP table preroute rules and policy list
sudo iptables -t nat -L --line-numbers

# Delete iptables rule and policy, ex: 4 is the line number
sudo iptables -t nat -D PREROUTING 4
