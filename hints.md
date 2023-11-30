запустить контейрер с переопределение CMD и аргументами

```docker run --rm --platform linux/amd64 --entrypoint /app/bingo shs --help```

```iptables -A OUTPUT -p tcp -d 8.8.8.8 --dport 80 -j REJECT```

```sudo iptables -I DOCKER-USER -p tcp -d 8.8.8.8 --dport 80 -j REJECT```

```sudo iptables -n -L -v```

```terraform state list```

```terraform state rm yandex_compute_instance_group.db```

```terraform import yandex_compute_instance_group.db cl10otj5r784lshsnl1j```

```terraform destroy -target yandex_compute_instance_group.nginx```

```bingo completion bash > bingo-prompt```

```cp bingo-prompt /usr/share/bash-completion/completions/bingo```

```complete -F __start_bingo bingo```

```yc compute instance-group get shs cl157t4o633kf9c1vdqe```

```tcpdump -i eth0 src 188.18.55.208 and dst port 80```

```sudo cp watchdog.service /etc/systemd/system/```

```sudo systemctl enable watchdog```

```sudo systemctl start watchdog```