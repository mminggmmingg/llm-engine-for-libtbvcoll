echo "host=$(hostname) lid=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}')"
for c in /sys/class/drm/card*-eDP-*; do echo "$(basename $c): status=$(cat $c/status) enabled=$(cat $c/enabled) dpms=$(cat $c/dpms)"; done
for b in /sys/class/backlight/*; do echo "backlight $(basename $b): $(cat $b/actual_brightness)/$(cat $b/max_brightness) bl_power=$(cat $b/bl_power)"; done
for d in /sys/bus/iio/devices/iio:device*; do printf '%s %s: ' $(basename $d) "$(cat $d/name)"; for f in $d/in_*raw $d/in_*input $d/in_attention* $d/in_proximity*; do [ -f $f ] && printf '%s=%s ' $(basename $f) "$(cat $f 2>&1 | head -1)"; done; echo; done 2>/dev/null
for p in /sys/class/power_supply/BAT*; do echo "$(basename $p): cap=$(cat $p/capacity)% status=$(cat $p/status) charge_behaviour=$(cat $p/charge_behaviour 2>/dev/null) end_threshold=$(cat $p/charge_control_end_threshold 2>/dev/null)"; done
for p in /sys/class/power_supply/*; do t=$(cat $p/type); [ "$t" = Battery ] || echo "$(basename $p) type=$t online=$(cat $p/online 2>/dev/null) usb_type=$(cat $p/usb_type 2>/dev/null)"; done
loginctl list-sessions --no-legend 2>/dev/null | head -5; gnome_idle=$(busctl --user call org.gnome.Mutter.IdleMonitor /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor GetIdletime 2>/dev/null); echo "gnome idle ms: $gnome_idle"
cat /sys/class/thermal/thermal_zone*/type 2>/dev/null | paste -sd' '; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | paste -sd' '
