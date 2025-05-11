#!/bin/bash

if [ "$UID" != 0 ]; then
  echo "Please run the script as root."
  exit 1 
fi
echo "MiniFaker [v1.0.0]"
case "$1" in
  cpu)
  case "$2" in
   revert) 
    umount -f /sys/devices/system/cpu 
    umount -f /proc/cpuinfo 
    umount -f /usr/bin/nproc
    rm -rf *cpu nproc
    echo done
    exit
  ;;
  *|make|do|generate)
  while [[ -z $branding ]]; do read -p "CPU name: " branding; done
  while [[ ! $nproc =~ [0-9]+ ]]; do read -p "CPU cores (e.g. 12 or 24): " nproc; done
  while [[ ! $(echo $cpufreq | sed -e 's/GHZ//'  -e 's/GHz//' -e 's/Ghz//' -e 's/ghz//' -e 's/gHz//' -e 's/ghZ//') =~ ^([0-9]+)(.|)([0-9]+)$ ]]; do read -p "CPU frequency (e.g 2.6GHz): " cpufreq; done
  cpufreq=$(echo "$(echo $cpufreq | sed -e 's/GHZ//'  -e 's/GHz//' -e 's/Ghz//' -e 's/ghz//' -e 's/gHz//' -e 's/ghZ//') * 100000000" | bc | sed 's/\.0//')
echo $cpufreq  
cat /proc/cpuinfo | head -n 26 > configure.fcpu

python3 << EOF
with open('configure.fcpu', 'r') as f:
        data = f.read().split('\n')

data[0] = data[0][:-1] + "<nproc>"
data[4] = data[4].split(":")[0] + ": <branding>"
with open('configure.fcpu', 'w') as f:
        f.write("".join(f"{i}\n" for i in data))
EOF
for i in $(seq 0 $(($nproc - 1))); do
        echo -ne "\rConfiguring CPUs... $i/$nproc"
        cat configure.fcpu | \
                sed "s+<nproc>+$i+g" | \
                sed "s+<branding>+$branding+g" \
                >> out.fcpu
done
echo -ne "\rConfiguring CPUs... $nproc/$nproc\n"
echo "Finishing configuration... OK"
sudo mount --bind $PWD/out.fcpu /proc/cpuinfo
# cpu freq
echo "Editing CPU frequency... OK"
cp /sys/devices/system/cpu cpu -r
echo "${cpufreq}" > cpu/cpu0/cpufreq/scaling_max_freq
echo "${cpufreq}" > cpu/cpu0/cpufreq/bios_limit

# spam create cpu
cd cpu
for i in $(seq $(nproc) $(($nproc - 1))); do
        echo -ne "\rGenerating CPUs... $i/$nproc" 
        cp cpu0 cpu$i -r
done
echo -ne "\rGenerating CPUs... $nproc/$nproc\n"
cd ..
mount --bind $PWD/cpu /sys/devices/system/cpu 
echo "Generating fake nproc... OK"
cat > nproc << EOF
#!/bin/sh
echo $nproc
EOF
chmod +x nproc
mount --bind nproc /usr/bin/nproc

echo "Total size: $(du -sh cpu)"
  esac
  ;;
  uptime)
  case $2 in
  revert)
  umount /proc/uptime 2>/dev/null
  umount /proc/uptime 2>/dev/null
  echo "reverted custom uptime changes"
  ;;
  *)
 echo "Enter time (e.g. 20d 16h 2m):" 
 read -r uptime
 touch ./uptime
  days=$(echo $uptime | grep -Eo '[0-9]?[0-9]?[0-9]?[0-9]?[0-9]d')
  days=${days//d}
  [ ! -z "$days" ] && days1="${days}" && { [ $days1 = 1 ] && days12="${days} day ago" || days12="${days} days ago"; } || days12=''
    mins=$(echo $uptime | grep -Eo '([0-6]0|[0-5]?[0-9]?)m')
    hours=$(echo $uptime | grep -Eo '([0-9]?[0-9]|1[0-9]|2[0-9])h')
          [ ! -z "$hours" ] && { [ ${hours//h} = 1 ] && hours=" ${hours//h} hour ago" || hours=" ${hours//h} hours ago"; }
  [ ! -z "${mins}" ] && mins=" ${mins//m} mins ago"
cputotal=$(cat /proc/uptime | awk '{print $2}')
echo "$(($(date +%s) - $(date -d "${days12} ${hours} ${mins}" +%s))).0 ${cputotal}" > ./uptime
mount --bind ./uptime /proc/uptime
echo "done"
;;
esac
  ;;
  ram)
  case $2 in 
    revert)
    umount /proc/meminfo -f 
    rm -rf meminfo 
    echo done
    exit
  ;;
  *|do|make|generate)
  while [[ ! $ram =~ ^[0-9]+$ ]]; do read -p "RAM in MB (e.g. 1024): " ram; done
  ram=$(echo "$ram * 1024" | bc)
  echo -ne "\rGenerating fake RAM file...\n"  
    cp /proc/meminfo meminfo
  chmod +w meminfo
  sed -Ei 's/^MemTotal:.*/MemTotal:       '"$ram"' kB/' meminfo
  sed -Ei 's/^MemAvailable:.*/MemAvailable: '"$((${ram}-$(($(grep 'MemTotal' /proc/meminfo | awk '{print $2}')-$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')))))"' kB/' meminfo 
  sed -Ei 's/^MemFree:.*/MemFree: '"$((${ram}-$(($(grep 'MemTotal' /proc/meminfo | awk '{print $2}')-$(grep 'MemFree' /proc/meminfo | awk '{print $2}')))))"' kB/' meminfo   
mount --bind $PWD/meminfo /proc/meminfo
  echo -ne "\rGenerating fake RAM file... done"
  esac
  ;;
  *) echo no argument supplied, exiting
  ;;
esac
