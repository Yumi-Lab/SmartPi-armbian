# H3 Overclock — SmartPi One

## TL;DR

Le CPU H3 (AllWinner) du SmartPi One est limité à **1296 MHz** par défaut.
Le patch kernel inclus active l'OPP **1368 MHz @ 1.40V**, qui est la fréquence
max stable testée.

Les fréquences 1488/1512 MHz ont été testées et abandonnées (instabilité).

## Détails techniques

### Formule PLL_CPUX

```
freq = 24 MHz x N x K / (M x P)
```

| Frequence | N  | K | M | P | Voltage | Status |
|-----------|----|---|---|---|---------|--------|
| 1296 MHz  | 27 | 2 | 1 | 1 | 1.34V   | stock  |
| 1368 MHz  | 19 | 3 | 1 | 1 | 1.40V   | actif  |

### Comment ça marche

Le patch `userpatches/kernel/archive/sunxi-6.18/0001-arm-dts-sun8i-h3-add-experimental-overclock-opp.patch`
active l'OPP 1368 MHz dans le Device Tree. Le gouverneur cpufreq monte
automatiquement jusqu'à cette fréquence sous charge.

## Vérification

```bash
# Frequence max
cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
# Attendu : 1368000

# Frequences disponibles
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies

# Temperature CPU
cat /sys/class/thermal/thermal_zone0/temp
```

## Prerequis

- Dissipateur thermique + ventilateur actif recommandé
- Throttling thermique protège à 85°C
